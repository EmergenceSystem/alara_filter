%%%-------------------------------------------------------------------
%%% @doc ALARA distributed entropy agent.
%%%
%%% Exposes the full ALARA public API as an em_disco agent.
%%%
%%% === Actions (JSON body field: "action") ===
%%%
%%%   generate_random_bytes   — N random bytes, base64-encoded.
%%%                             Param: "n" (integer, default 32).
%%%
%%%   generate_random_bits    — N random bits as a 0/1 list.
%%%                             Param: "n" (integer, default 64).
%%%
%%%   generate_random_int     — Non-negative integer from NBits entropy.
%%%                             Param: "n_bits" (integer, default 128).
%%%
%%%   get_nodes               — PIDs of all live local entropy workers.
%%%
%%%   get_cluster_nodes       — Full cluster view: local PIDs + remote
%%%                             node statuses.
%%%
%%% Default (no action, plain string, or unknown): generate_random_bytes
%%% with n=32.
%%%
%%% Handler contract: handle/2 (Body, Memory) -> {RawList, Memory}.
%%% @end
%%%-------------------------------------------------------------------
-module(alara_filter_app).
-behaviour(application).

-export([start/2, stop/1]).
-export([handle/2, base_capabilities/0]).

%%====================================================================
%% Capability cascade
%%====================================================================

-spec base_capabilities() -> [binary()].
base_capabilities() ->
    em_filter:base_capabilities() ++ [<<"alara">>, <<"entropy">>,
                                      <<"random">>, <<"erlang">>,
                                      <<"distributed">>].

%%====================================================================
%% Application behaviour
%%====================================================================

start(_Type, _Args) ->
    em_filter:start_agent(alara_filter, ?MODULE, #{
        capabilities => base_capabilities()
    }),
    {ok, self()}.

stop(_State) ->
    em_filter:stop_agent(alara_filter).

%%====================================================================
%% Agent handler
%%====================================================================

-spec handle(binary(), map()) -> {list(), map()}.
handle(Body, Memory) when is_binary(Body) ->
    {dispatch(Body), Memory};
handle(_Body, Memory) ->
    {[], Memory}.

%%====================================================================
%% Dispatch
%%====================================================================

dispatch(Body) ->
    Params = decode_params(Body),
    case maps:get(<<"action">>, Params, <<"generate_random_bytes">>) of
        <<"generate_random_bytes">> ->
            N = get_int(<<"n">>, Params, 32),
            [bytes_embryo(alara:generate_random_bytes(N), N)];
        <<"generate_random_bits">> ->
            N = get_int(<<"n">>, Params, 64),
            [bits_embryo(alara:generate_random_bits(N), N)];
        <<"generate_random_int">> ->
            NBits = get_int(<<"n_bits">>, Params, 128),
            [int_embryo(alara:generate_random_int(NBits), NBits)];
        <<"get_nodes">> ->
            nodes_embryos(alara:get_nodes());
        <<"get_cluster_nodes">> ->
            cluster_embryos(alara:get_cluster_nodes());
        _ ->
            N = get_int(<<"n">>, Params, 32),
            [bytes_embryo(alara:generate_random_bytes(N), N)]
    end.

%%====================================================================
%% Embryo builders
%%====================================================================

bytes_embryo({error, Reason}, _N) ->
    error_embryo(<<"generate_random_bytes">>, Reason);
bytes_embryo(Bytes, N) when is_binary(Bytes) ->
    #{<<"properties">> => #{
        <<"url">>    => <<"https://hex.pm/packages/alara">>,
        <<"title">>  => iolist_to_binary(
                            io_lib:format("~B random bytes", [N])),
        <<"resume">> => base64:encode(Bytes),
        <<"source">> => <<"alara">>
    }}.

bits_embryo({error, Reason}, _N) ->
    error_embryo(<<"generate_random_bits">>, Reason);
bits_embryo(Bits, N) when is_list(Bits) ->
    BitsStr = iolist_to_binary([integer_to_list(B) || B <- Bits]),
    #{<<"properties">> => #{
        <<"url">>    => <<"https://hex.pm/packages/alara">>,
        <<"title">>  => iolist_to_binary(
                            io_lib:format("~B random bits", [N])),
        <<"resume">> => BitsStr,
        <<"source">> => <<"alara">>
    }}.

int_embryo({error, Reason}, _NBits) ->
    error_embryo(<<"generate_random_int">>, Reason);
int_embryo(Int, NBits) when is_integer(Int) ->
    #{<<"properties">> => #{
        <<"url">>    => <<"https://hex.pm/packages/alara">>,
        <<"title">>  => iolist_to_binary(
                            io_lib:format("random integer (~B bits)", [NBits])),
        <<"resume">> => integer_to_binary(Int),
        <<"source">> => <<"alara">>
    }}.

nodes_embryos(Pids) when is_list(Pids) ->
    [#{<<"properties">> => #{
        <<"url">>    => <<"https://hex.pm/packages/alara">>,
        <<"title">>  => iolist_to_binary(io_lib:format("~p", [Pid])),
        <<"resume">> => <<"local entropy worker">>,
        <<"source">> => <<"alara">>
    }} || Pid <- Pids];
nodes_embryos(_) -> [].

cluster_embryos(#{local := Local, remote := Remote}) ->
    LocalEmb = [#{<<"properties">> => #{
        <<"url">>    => <<"https://hex.pm/packages/alara">>,
        <<"title">>  => iolist_to_binary(io_lib:format("~p", [Pid])),
        <<"resume">> => <<"local worker">>,
        <<"source">> => <<"alara">>
    }} || Pid <- Local],
    RemoteEmb = [#{<<"properties">> => #{
        <<"url">>    => <<"https://hex.pm/packages/alara">>,
        <<"title">>  => atom_to_binary(Node, utf8),
        <<"resume">> => atom_to_binary(Status, utf8),
        <<"source">> => <<"alara">>
    }} || {Node, Status} <- Remote],
    LocalEmb ++ RemoteEmb;
cluster_embryos(_) -> [].

error_embryo(Action, Reason) ->
    #{<<"properties">> => #{
        <<"url">>    => <<"https://hex.pm/packages/alara">>,
        <<"title">>  => iolist_to_binary(
                            io_lib:format("error: ~s", [Action])),
        <<"resume">> => iolist_to_binary(io_lib:format("~p", [Reason])),
        <<"source">> => <<"alara">>
    }}.

%%====================================================================
%% Helpers
%%====================================================================

decode_params(Body) ->
    try json:decode(Body) of
        Map when is_map(Map) -> Map;
        _                    -> #{}
    catch _:_ -> #{} end.

get_int(Key, Params, Default) ->
    case maps:get(Key, Params, Default) of
        V when is_integer(V), V > 0 -> V;
        B when is_binary(B) ->
            try binary_to_integer(B) catch _:_ -> Default end;
        _ -> Default
    end.
