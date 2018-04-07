use Bitwise
require Logger

defmodule FlexId do
  @moduledoc """
  Documentation for FlexId.
  """

  defstruct sequence_bits: 6,
            partition_bits: 6,
            checksum_bits: 4,
            sequence_mask: 0x3F,
            partition_mask: 0x3F,
            checksum_mask: 0x0F,
            epoch: 946_684_800_000,
            seq: 0,
            ms: 0

  @doc """
  Start an agent that can be used generate IDs with the given parameters.
  Ids are composed of 4 value:
    - time in ms
    - rolling sequence counter
    - partition used to segratate ids; this could be hard-coded by node or geo-region
      or be a hash to shard data by user
    - Luhn mod 16 checksum to check for incorrectly typed ids
  ## Parameters
    - epoch: the epoch to start the ids at in ms; defaults to `946_684_800_000` (2000-01-01 0:00 UTC)
    - sequence_bits: how many bits should be used for sub-millisecond precision; defaults to 6 for 64 ids/ms
    - partition_bits: how many bits should be used to identify partitions in the ids; defaults to 6 for 64 partitions
    - checksum_bits: how many bits should be used for checksum to detect invalid ids; must be 0 or 4, defaults to 4
  ## Usage
    The default parameters have the following characteristics
    - a time range of 2231 years, from 2000 to 4229 (afterwhich values become 64-bits and will be negative when using signed integers)
    - a theoretical maximum of 64 ids/ms
    - 64 partitions
    - a 4-bit checksum to catch errors should ids need to be typed in manually
  """
  def start_link(
        epoch \\ 946_684_800_000,
        sequence_bits \\ 6,
        partition_bits \\ 6,
        checksum_bits \\ 4
      ) do
    Agent.start_link(FlexId, :make, [epoch, sequence_bits, partition_bits, checksum_bits])
  end

  def make(epoch, sequence_bits, partition_bits, checksum_bits) do
    %FlexId{
      epoch: epoch,
      sequence_bits: sequence_bits,
      sequence_mask: make_mask(sequence_bits),
      partition_bits: partition_bits,
      partition_mask: make_mask(partition_bits),
      checksum_bits: checksum_bits,
      checksum_mask: make_mask(checksum_bits)
    }
  end

  def extract_raw_millis(agent, value) do
    Agent.get(agent, fn state ->
      value >>> (state.sequence_bits + state.partition_bits + state.checksum_bits)
    end)
  end

  def extract_millis(agent, value) do
    Agent.get(agent, fn state ->
      (value >>> (state.sequence_bits + state.partition_bits + state.checksum_bits)) + state.epoch
    end)
  end

  def extract_sequence(agent, value) do
    Agent.get(agent, fn state ->
      value >>> (state.partition_bits + state.checksum_bits) &&& state.sequence_mask
    end)
  end

  def extract_partition(agent, value) do
    Agent.get(agent, fn state -> value >>> state.checksum_bits &&& state.partition_mask end)
  end

  def extract_checksum(agent, value) do
    Agent.get(agent, fn state -> value &&& state.checksum_mask end)
  end

  def log(agent) do
    Agent.cast(agent, fn state ->
      ms =
        round(
          :math.pow(2, 63 - state.sequence_bits - state.partition_bits - state.checksum_bits - 1)
        )

      yr = round(ms / 1000 / 60 / 60 / 24 / 365)
      fr = DateTime.from_unix!(state.epoch, :millisecond)
      to = DateTime.from_unix!(state.epoch + ms, :millisecond)
      seq = round(:math.pow(2, state.sequence_bits))
      shd = round(:math.pow(2, state.partition_bits))

      Logger.info(
        "Ids have a time range of #{yr} years (#{fr} to #{to}), #{seq} sequences, #{shd} partitions, #{
          state.checksum_bits
        } checksum bits"
      )

      state
    end)
  end

  defp make_mask(bits) do
    Enum.reduce(1..bits, 0, fn _, acc -> acc <<< 1 ||| 1 end)
  end

  @doc """
  Helper for generating a 16-bit partition value from the last two bytes of the sha1 hash of a text value.

  ## Examples
      partition = FlexId.make_partition("username")
  """
  def make_partition(text) do
    hash = :crypto.hash(:sha, text)
    <<_::binary-18, partition::unsigned-big-integer-16>> = hash
    partition
  end

  @doc """
  Generate an Id Value.

  ## Examples
      iex> {:ok, fid} = FlexId.start_link
      value = FlexId.generate(fid, 0xB1)
  """
  def generate(agent, partition) when is_integer(partition) do
    Agent.get_and_update(agent, fn state ->
      ms = :os.system_time(:millisecond) - state.epoch
      seq = if state.ms == ms, do: state.seq + 1, else: 0
      masked_seq = seq &&& state.sequence_mask

      if seq > 0 && masked_seq == 0 do
        raise("sequence overflow")
      end

      value =
        ms <<< (state.sequence_bits + state.partition_bits + state.checksum_bits) |||
          masked_seq <<< (state.partition_bits + state.checksum_bits) |||
          (partition &&& state.partition_mask) <<< state.checksum_bits

      value = if state.checksum_bits == 4, do: checksum(value), else: value

      {value, state |> Map.put(:seq, seq) |> Map.put(:ms, ms)}
    end)
  end

  def checksum(input) do
    {_, sum, _} =
      1..15
      |> Enum.reduce({input >>> 4, 0, 2}, fn _, {input, sum, factor} ->
        addend = factor * (input &&& 0xF)
        addend = div(addend, 0xF) + rem(addend, 0xF)
        {input >>> 4, sum + addend, if(factor == 2, do: 1, else: 2)}
      end)

    remainder = rem(sum, 0xF)
    check = rem(0xF - remainder, 0xF)
    input ||| check
  end

  def verify_checksum(input) do
    {_, sum, _} =
      0..15
      |> Enum.reduce({input, 0, 1}, fn _, {input, sum, factor} ->
        addend = factor * (input &&& 0xF)
        addend = div(addend, 0xF) + rem(addend, 0xF)
        {input >>> 4, sum + addend, if(factor == 2, do: 1, else: 2)}
      end)

    0 == rem(sum, 0xF)
  end
end
