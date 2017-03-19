use Bitwise

defmodule FlexId do
  @moduledoc """
  Documentation for FlexId.
  """

  defstruct sequence_bits: 8,
            shard_bits: 8,
            sequence_mask: 0xFF,
            shard_mask: 0xfF,
            epoch: 0,
            sequence: 0

  def new() do
    %FlexId{}
  end

  def set_sequence_bits(id, bits) when bits >=0 and bits < 15 do
    %{id | sequence_bits: bits, sequence_mask: make_mask(bits)}
  end

  def set_shard_bits(id, bits) when bits >=0 and bits < 15 do
    %{id | shard_bits: bits, shard_mask: make_mask(bits)}
  end

  def set_sequence(id, seq) do
    %{id | sequence: seq}
  end

  def set_epoch(id, epoch) do
    %{id | epoch: epoch}
  end

  def extract_raw_millis(id, value) do
    value >>> (id.sequence_bits + id.shard_bits)
  end

  def extract_millis(id, value) do
    (value >>> (id.sequence_bits + id.shard_bits)) + id.epoch
  end

  def extract_sequence(id, value) do
    (value >>> id.shard_bits) &&& id.sequence_mask
  end

  def extract_shard(id, value) do
      value &&& id.shard_mask
  end

  defp make_mask(bits) do
    Enum.reduce(1..bits, 0, fn {_, m} -> (m <<< 1) ||| 1 end)
  end

  @doc """
  Generate an Id Value.

  ## Examples
      iex> id = FlexId.new
      {value, id} = FlexId.generate(id, 0xB1)
  """
  def generate(id, shard) when is_integer(shard) do
    millis = :os.system_time(:millisecond) - id.epoch
    value = millis <<< (id.sequence_bits + id.shard_bits)
      ||| (id.sequence &&& id.sequence_mask) <<< (id.shard_bits)
      ||| (shard &&& id.shard_mask)

    id = %{id | sequence: id.sequence + 1}
    { value, id }
  end

  @doc """
  Generate an Id Value.

  ## Examples
      iex> id = FlexId.new
      {value, id} = FlexId.generate(id, "username")
  """
  def generate(id, text) when is_binary(text) do
    hash = :crypto.hash(:sha, text)
    <<_::binary-18, shard::unsigned-big-integer-16>> = hash
    generate(id, shard)
  end
end
