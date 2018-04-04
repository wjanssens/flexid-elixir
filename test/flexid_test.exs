defmodule FlexIdTest do
  use ExUnit.Case, async: true

  test "defaults" do
    {:ok, fid} = FlexId.start_link()
    FlexId.log(fid)
    sh = FlexId.make_partition("test")
    assert 0xBBD3 == sh

    v1 = FlexId.generate(fid, sh)

    now = :os.system_time(:millisecond)
    assert now - FlexId.extract_millis(fid, v1) < 5
    assert 0x00 == FlexId.extract_sequence(fid, v1)
    assert 0x13 == FlexId.extract_partition(fid, v1)

    v2 = FlexId.generate(fid, sh)
    assert 0x01 == FlexId.extract_sequence(fid, v2)
  end

  test "eights" do
    {:ok, fid} = FlexId.start_link(0, 8, 8, 0)
    FlexId.log(fid)
    sh = FlexId.make_partition("test")
    assert 0xBBD3 == sh

    v1 = FlexId.generate(fid, sh)

    now = :os.system_time(:millisecond)
    assert now - FlexId.extract_millis(fid, v1) < 5
    assert 0x00 == FlexId.extract_sequence(fid, v1)
    assert 0xD3 == FlexId.extract_partition(fid, v1)

    v2 = FlexId.generate(fid, sh)
    assert 0x01 == FlexId.extract_sequence(fid, v2)
  end

  test "sixes" do
    {:ok, fid} = FlexId.start_link(0, 6, 6, 4)
    FlexId.log(fid)
    sh = FlexId.make_partition("test")
    assert 0xBBD3 == sh

    v1 = FlexId.generate(fid, sh)

    now = :os.system_time(:millisecond)
    assert now - FlexId.extract_millis(fid, v1) < 5
    assert 0x00 == FlexId.extract_sequence(fid, v1)
    assert 0x13 == FlexId.extract_partition(fid, v1)

    v2 = FlexId.generate(fid, sh)
    assert 0x01 == FlexId.extract_sequence(fid, v2)
  end

  test "checksum" do
    assert 0 == FlexId.checksum(0x00000000)
    assert 0x7FFFFFF7 == FlexId.checksum(0x7FFFFFF0)
    assert !FlexId.verify_checksum(0x7FFFFFF3)
    assert FlexId.verify_checksum(0x7FFFFFF7)
  end
end
