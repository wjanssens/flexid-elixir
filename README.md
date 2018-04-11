# FlexId

This library is inspired by two different id generation strategies: type 1 UUIDs, and Instragam's Ids.

* Type 1 UUIDs have 60 bits for time, 14 bits for clock sequence, 48 bits for node, 4 version bits, 2 variant bits
    * 128 bit numbers are difficult to deal with in most programming languages and storage mediums
    * 60 bits of ms results in a rollover of 36558901 years which seems like overkill
    * 14 bits clock sequence allows for 32767 ids per millisecond
    * 48 bits for node allows for 281474976710655 unique nodes (i.e. MAC addresses)
* Instragram IDs have 41 bits for time, 13 bits for shard id, 10 bits for sequence
    * 64 bit numbers are perfect for languages and storage mediums that only support 64 bit integers
    * 41 bits for ms results in negative values in 34 years, and a rollover in only 69 years
      from their custom epoch of Jan 1, 2011 (i.e. 2080)
      which seems like insufficient longevity
    * 13 bits for shard allows 8191 shards which seems like overkill
    * 10 bits sequence allows for 1024 ids per millisecond which seems very reasonable
* Mongo IDs have 32 bits for time, 24 bits for machine ID, 16 bits for process ID, 24 bytes for counter
    * 96 bit numbers seem don't fit nicely into any language type system
    * 96 bit numbers cannot be obfuscated with HashId
    * 32 bits for seconds since UNIX epoch results in rollover in 136 years since epoch (i.e. 2106)
      which seems like insufficient longevity
    * 24 bits for counter results in 4294967296 IDs per second per machine which seems like overkill
* By default, FlexIDs have 47 bits for time, 6 bits for sequence, 6 bits for shard, 4 bits for checksum
    * 64 bit numbers are perfect for languages and storage mediums that only support 64 bit integers
    * 48 bits for ms results in negative values in 4462 years, and a rollover in 8925 years
    * 6 bits sequence allows for 64 ids per millisecond
    * 6 bits partitions allows for 64 partitions / shards
    * 4 bits checksum (using Luhn mod-16 algorithm)

The exact division is configurable, but the following guidelines should be followed:
* 1 bit constant 0 (allows for unsigned integer storage and HashId compatibility)
* 43-47 bits for time, for between 557 - 8925 of positive values
* 4-12 bits for sequence, for between 16 and 4096 ids/ms
* 4-12 bits for partitioning, for between 16 and 4096 shards / partitions
* 0-4 bits for parity / checksum
* the most common configurations are 47/8/4/4, 45/6/8/4, and 47/6/6/4 but you should evaluate your longevity and
  scalability requirements and set the values accordingly.
* There is no minimum number of bits for sequence, or shard, so you could set them to 0 but this is not recommended,
  even in a single node system, as it would not allow for any future expansion.
* It may be desirable to use 4 bits, 8 bits, or 12 bits for sequence and partition as that will result
  in IDs that allow you to directly read the input values.

The order of the components is debatable, but this implementation adopts the same order as type 1 UUIDs which
results in an order of decreasing change; time, sequence, partition.  
This differs from the order adopted by Instagram, so this library cannot be used to generate Instagram compatible Ids.

There are many ways that you may decide to partition your ID space:
* By Row: Splitting up a database row-wise, typically by user.
    * Each shard needs to be assigned a unique ID and data is mapped onto a shard using a shard key.
    * The number of physical shards may be fewer than the number of logical shards.
      The easiest way to determine the physical shard from the logical shard is by
      inspecting the least significant bits of the shard.
* By Entity: Splitting up your ID space base on table or class
    * If all entities share an ID space then you don't need to reserve
      any space for them in the shard.  This is the preferred scenario.
    * If it's desirable to identify the type of entity from the ID then some number of bits of the shard need
      to be assigned to identify the entity.
* By Domain: Splitting up a database based on business domain.
    * If domains are completely independent and it's OK for IDs to overlap between domains then
      none of the shard bits need to be assigned to identify the domain.
      This is the preferred scenario.
    * If domains share an ID space then some number of bits of the constant field should be
      assigned to identify the domain and prevent collisions between domains.
* By Cluster: Using multiple application servers to access the same database.
    * If your application servers assign IDs then some number of bits of the shard need to be assigned
      to identify the server to prevent collisions between application servers.
    * As more bits are allocated to cluster, fewer bits may be needed for sequence.
* By Region: Using multiple application servers to access the same database.
    * If your application servers assign IDs then some number of bits of the shard need to be assigned
      to identify the server to prevent collisions between application servers.
    * As more bits are allocated to cluster, fewer bits may be needed for sequence.

Other strategies for generating IDs that aren't very interesting are:
* Type 4 Random UUID
    * chance of collision only increases as data grows
    * not sequential
    * 128-bits
* High/Low
    * has single point of failure when new high is required
* Linear Chunk
    * has single point of failure when new chunk is required
* DB Serial Columns
    * vendor specific implementations differ on the timing of the id generation
    * must be assigned by the database
    * not applicable for NoSQL applications
* Max+1
    * can be expensive (slow) as data grows
    * not applicable for NoSQL applications
* Twitter Snowflake
    * retired
    * requires additional server infrastructure

Further Reading:
* https://engineering.instagram.com/sharding-ids-at-instagram-1cf5a71e5a5c#.vdwtymfgu
* http://code.flickr.net/2010/02/08/ticket-servers-distributed-unique-primary-keys-on-the-cheap/
* http://rob.conery.io/2014/05/29/a-better-id-generator-for-postgresql/
* http://hashids.org/

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `flexid` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:flexid, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/flexid](https://hexdocs.pm/flexid).
