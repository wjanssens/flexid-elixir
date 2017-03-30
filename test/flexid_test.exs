defmodule FlexIdTest do
  use ExUnit.Case, async: true

  test "defaults" do
    {:ok, fid} = FlexId.start_link()
    FlexId.log(fid)
    sh = FlexId.make_shard("test")
    assert 0xBBD3 == sh

    v1 = FlexId.generate(fid, sh)

    now = :os.system_time(:millisecond)
    assert now - FlexId.extract_millis(fid, v1) < 5
    assert 0x00 == FlexId.extract_sequence(fid, v1)
    assert 0xD3 == FlexId.extract_shard(fid, v1)

    v2 = FlexId.generate(fid, sh)
    assert 0x01 == FlexId.extract_sequence(fid, v2)
  end

  test "sixes" do
      {:ok, fid} = FlexId.start_link(0, 6, 6)
      #FlexId.log(fid)
      sh = FlexId.make_shard("test")
      assert 0xBBD3 == sh

      v1 = FlexId.generate(fid, sh)

      now = :os.system_time(:millisecond)
      assert now - FlexId.extract_millis(fid, v1) < 5
      assert 0x00 == FlexId.extract_sequence(fid, v1)
      assert 0x13 == FlexId.extract_shard(fid, v1)

      v2 = FlexId.generate(fid, sh)
      assert 0x01 == FlexId.extract_sequence(fid, v2)
  end

end