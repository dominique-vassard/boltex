# BOLT V3 INFORMATION

Since Neo4j 3.5, boltv3 is here!  

Nothing changes regarding types / structures, only messages are impacted.  

## Metadata
`Metadata` is a structure used as parameters by `RUN` and `BEGIN`. It is the same for both messages.  
It purpose is not well defined yet. Needs research...

Name | type | description
-----|------|------------
bookmarks | list(string) | A list of bookmarks to be used
tx_timeout | int | the query timeout (milliseconds)
tx_metadata | map | ?

## HELLO
This message replaces `INIT` and serves the same purpose.  

### Required parameters
Name | type | description
-----|------|------------    
user_agent | string | similar to _client_name_ used in `INIT`
scheme | string | |
credentials | string | |
principal | string | |

#### Example  
``HELLO %{credentials: "password", principal: "neo4j", scheme: "basic", user_agent: "Boltex/0.5.0"}``

### Return
`SUCCESS`   
or  
`FAILURE`  with an error string  

When successfull, return contains the following data
Name | type | description
-----|------|------------
server | string | The neo4j server version
connection_id | string ||

#### Example
``SUCCESS %{"connection_id" => "bolt-31", "server" => "Neo4j/3.5.1"}``

## RUN (Upated message)
`RUN` message still exists in bolt v1 and v2 and is used to send a query to the server. The server will respond with an acknowledglement and information about the result. Be aware that the result is not in the result. You have to send a `PULL_ALL` message to get the result.

### Required parameters
Name | type | description
-----|------|------------    
_query | string | the query to be executed
_parameters | map | The parameters to be used by query |
_metadata | map | The metadata to be used (see metadata) |

#### Examples
``"RETURN 1 as num"  %{}  %{}``
``"MATCH (:Person {uid: {uid}} RETURN p as person"  %{uid: 5}  %{tx_timeout: 5000}``

### Return
`SUCCESS` with data
or 
`FAILURE`  with an error string  

When successfull, return contains the following data

Name | type | description
-----|------|------------
fields | list(string) | fields that will be found in result
t_first | int | When the result will be available (replaces `result_available_after`)

#### Example
``SUCCESS  %{"fields" => ["num"], "t_first" => 0}``

## PULL_ALL (Upated message)
`PULL_ALL` message still exists in bolt v1 and v2 is used to fetch result from a previous `RUN` message.

### Required parameters
None

#### Example
``PULL_ALL``

### Return
multiple `RECORD` messages and a final `SUCCESS`  
or  
`FAILURE` with an error string  

First, `PULL_ALL` will return `RECORD`s containing the query result.  
When this stream is complete, it will return a `SUCCESS`  message containing
Name | type | description
-----|------|------------
bookmark | string | A bookmark name
stats | map | The stats summary (only for write operations)
t_last | int | time for result consumption (replaces `result_consumed_after`)
type | string | The operation type: **r**ead or **w**rite

Examples:
```
# Read
RECORD [1]
SUCCESS %{"bookmark" => "neo4j:bookmark:v1:tx16732", "t_last" => 0, "type" => "r"}

# Write
SUCCESS ~ %{"bookmark" => "neo4j:bookmark:v1:tx16733", "stats" => %{"labels-added" => 1, "nodes-created" => 1, "properties-set" => 2}, "t_last" => 0, "type" => "w"}
```

## BEGIN
Signature: 0x11  

`BEGIN` starts a transaction.   


### Required parameters
Name | type | description
-----|------|------------    
_metadata | map | The metadata to be used (see metadata) |

#### Example
``BEGIN %{}``  
``BEGIN %{bookmarks: ["neo4j:bookmark:v1:tx111"]}``

### Return
`SUCCESS` message without data
or
`FAILURE` with an error string

#### Example
``SUCCESS %{}``

## COMMIT
Signature: 0x12  

`COMMIT` commits the currently open transaction.

### Required parameters
None

#### Example
``COMMIT``

### Return
`SUCCESS` with data  
or  
`FAILURE`  with an error string  

When successfull, return contains the following data:  

Name | type | description
-----|------|------------
bookmark | string | A bookmark name

#### Example
``SUCCESS %{"bookmark" => "neo4j:bookmark:v1:tx16732"}``

## ROLLBACK
Signature 0x13  

`ROLLBACK` rollbacks the currently open transaction.  

### Required parameters
None

#### Example
``ROLLBACK``

### Return
`SUCCESS` message without data  
or  
`FAILURE` with an error string

#### Example
``SUCCESS %{}``

## GOODBYE
Signature: 0x02

`GOODBYE` closes the open connection

### Required parameters
None

#### Example
``GOODBYE``

### Return
Nothing because connection is closed. Server doesn't sent anything back!