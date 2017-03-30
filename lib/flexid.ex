use Bitwise
require Logger

defmodule FlexId do
  @moduledoc """
  Documentation for FlexId.
  """

  defstruct sequence_bits: 8,
            shard_bits: 8,
            sequence_mask: 0xFF,
            shard_mask: 0xFF,
            epoch: 0,
            sequence: 0

  def start_link() do
    Agent.start_link(fn -> %FlexId{} end)
  end

  def start_link(epoch, sequence_bits, shard_bits) do
    Agent.start_link(fn -> %FlexId{
      epoch: epoch,
      sequence_bits: sequence_bits,
      sequence_mask: make_mask(sequence_bits),
      shard_bits: shard_bits,
      shard_mask: make_mask(shard_bits)
    } end)
  end

  def set_sequence(agent, seq) do
    Agent.update(agent, fn state -> %{state | sequence: seq} end)
  end

  def extract_raw_millis(agent, value) do
    Agent.get(agent, fn state -> value >>> (state.sequence_bits + state.shard_bits) end)
  end

  def extract_millis(agent, value) do
    Agent.get(agent, fn state -> (value >>> (state.sequence_bits + state.shard_bits)) + state.epoch end)
  end

  def extract_sequence(agent, value) do
    Agent.get(agent, fn state -> (value >>> state.shard_bits) &&& state.sequence_mask end)
  end

  def extract_shard(agent, value) do
    Agent.get(agent, fn state -> value &&& state.shard_mask end)
  end

  def log(agent) do
    Agent.cast(agent, fn state ->
      ms = round(:math.pow 2, (64 - state.sequence_bits - state.shard_bits - 1))
      yr = round(ms / 1000 / 60 / 60 / 24 / 365)
      fr = DateTime.from_unix! state.epoch, :millisecond
      to = DateTime.from_unix! (state.epoch + ms), :millisecond
      seq = round(:math.pow 2, state.sequence_bits)
      shd = round(:math.pow 2, state.shard_bits)
      Logger.info "Ids have a time range of #{yr} years (#{fr} to #{to}), #{seq} sequences, #{shd} shards"
      state
   end)
  end

  defp make_mask(bits) do
    Enum.reduce(1..bits, 0, fn(_, acc) -> (acc <<< 1) ||| 1 end)
  end

  @doc """
  Helper for generating a 16-bit shard value from the last two bytes of the sha1 hash of a text value.

  ## Examples
      shard = FlexId.make_shard("username")
  """
  def make_shard(text) do
    hash = :crypto.hash(:sha, text)
    <<_::binary-18, shard::unsigned-big-integer-16>> = hash
    shard
  end

  @doc """
  Generate an Id Value.

  ## Examples
      iex> {:ok, fid} = FlexId.start_link
      value = FlexId.generate(fid, 0xB1)
  """
  def generate(agent, shard) when is_integer(shard) do
    Agent.get_and_update(agent, fn state ->
      millis = :os.system_time(:millisecond) - state.epoch
      value = millis <<< (state.sequence_bits + state.shard_bits)
        ||| (state.sequence &&& state.sequence_mask) <<< (state.shard_bits)
        ||| (shard &&& state.shard_mask)

      { value, %{state | sequence: state.sequence + 1} }
    end)
  end

end
