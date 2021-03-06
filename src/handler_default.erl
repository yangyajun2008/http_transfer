%%%-------------------------------------------------------------------
%%% @author yangyajun03
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. 三月 2018 下午2:56
%%%-------------------------------------------------------------------
-module(handler_default).
-author("yangyajun03").

-include("http_transfer.hrl").
-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

init(_Transport, Req, []) ->
    {ok, Req, undefined}.

handle(Req, State) ->
    {Method, Req1} = cowboy_req:method(Req),
    {Path, Req2} = cowboy_req:path(Req1),
    Req3 = cross_domain(Req2),
    {ok, Req4} = parse_handle(Method, Path, Req3),
    {ok, Req4, State}.

parse_handle(_Method, <<"/favicon.ico">>, Req) ->
    lager:error("unsupport path, req:~p", [Req]),
    cowboy_req:reply(404, Req);
parse_handle(<<"OPTIONS">>, _Path, Req) ->
    cowboy_req:reply(200, [
        {<<"Access-Control-Allow-Origin">>, <<"*">>},
        {<<"Access-Control-Allow-Headers">>,
            <<"Content-Type, X-Requested-With, Authorization, Date">>},
        {<<"Access-Control-Allow-Methods">>, <<"GET,POST,PUT,DELETE,OPTIONS">>}
    ], <<>>, Req);
parse_handle(<<"GET">>, Path, Req) ->
    {Qs, Req1} = cowboy_req:qs(Req),
    {Headers, Req2} = cowboy_req:headers(Req1),
    {Url, NewHeaders} = get_url_headers(Path, Headers),
    lager:info("method:get, qs:~p, req:~p", [Qs, Req]),
    NewUrl = Url ++ "?" ++ binary_to_list(Qs),
    {Code, Res} = http_ibrowse:ibrowse_send(get, NewUrl, NewHeaders, [], ?OPTION, ?TIMEOUT),
    cowboy_req:reply(Code, [], Res, Req2);
parse_handle(<<"POST">>, Path, Req) ->
    {ok, Body, Req1} = cowboy_req:body(Req),
    {Headers, Req2} = cowboy_req:headers(Req1),
    {Url, NewHeaders} = get_url_headers(Path, Headers),
    lager:info("method:post, body:~p, req:~p", [Body, Req]),
    {Code, Res} = http_ibrowse:ibrowse_send(post, Url, NewHeaders, Body, ?OPTION, ?TIMEOUT),
    cowboy_req:reply(Code, [], Res, Req2);
parse_handle(<<"PUT">>, Path, Req) ->
    {ok, Body, Req1} = cowboy_req:body(Req),
    {Headers, Req2} = cowboy_req:headers(Req1),
    {Url, NewHeaders} = get_url_headers(Path, Headers),
    lager:info("put:post, body:~p, req:~p", [Body, Req]),
    {Code, Res} = http_ibrowse:ibrowse_send(put, Url, NewHeaders, Body, ?OPTION, ?TIMEOUT),
    cowboy_req:reply(Code, [], Res, Req2);
parse_handle(<<"DELETE">>, Path, Req) ->
    {Qs, Req1} = cowboy_req:qs(Req),
    {Headers, Req2} = cowboy_req:headers(Req1),
    {Url, NewHeaders} = get_url_headers(Path, Headers),
    lager:info("method:delete, qs:~p, req:~p", [Qs, Req]),
    NewUrl = Url ++ "?" ++ binary_to_list(Qs),
    {Code, Res} = http_ibrowse:ibrowse_send(delete, NewUrl, NewHeaders, [], ?OPTION, ?TIMEOUT),
    cowboy_req:reply(Code, [], Res, Req2);
parse_handle(Method, _Path, Req) ->
    lager:error("unsupport method:~p, req:~p", [Method, Req]),
    cowboy_req:reply(405, Req).

terminate(_Reason, _Req, _State) ->
    ok.

parse_path(Path) ->
    [<<>>, PName | Other] = binary:split(Path, <<"/">>, [global]),
    RealPath = lists:foldl(fun(N, <<>>) -> <<"/", N/binary>>;
        (N, Bin) -> <<Bin/binary, "/", N/binary>> end, <<>>, Other),
    {PName, RealPath}.

get_env_host(PName) ->
    {ok, Hosts} = application:get_env(?APPNAME, hosts),
    case proplists:get_value(PName, Hosts) of
        undefined ->
            {error, empty};
        Domain ->
            {ok, Domain}
    end.

%%跨域初始化
cross_domain(Req) ->
    cowboy_req:set_resp_header(<<"Access-Control-Allow-Origin">>, <<"*">>, Req).

set_headers(Headers, Domain) ->
    %替换host
    <<"http://", Host/binary>> = list_to_binary(Domain),
    lists:keydelete(<<"host">>, 1, Headers) ++ [{<<"host">>, Host}].

get_url_headers(Path, Headers) ->
    {PName, RealPath} = parse_path(Path),
    {ok, Domain} = get_env_host(PName),
    {Domain ++ binary_to_list(RealPath), set_headers(Headers, Domain)}.