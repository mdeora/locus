%% Copyright (c) 2017-2019 Guilherme Andrade
%%
%% Permission is hereby granted, free of charge, to any person obtaining a
%% copy  of this software and associated documentation files (the "Software"),
%% to deal in the Software without restriction, including without limitation
%% the rights to use, copy, modify, merge, publish, distribute, sublicense,
%% and/or sell copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
%% DEALINGS IN THE SOFTWARE.
%%
%% locus is an independent project and has not been authorized, sponsored,
%% or otherwise approved by MaxMind.
%%
%% locus includes code extracted from OTP source code, by Ericsson AB,
%% released under the Apache License 2.0.

%% @private
-module(locus_sup).
-behaviour(supervisor).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/0]).                      -ignore_xref({start_link,0}).
-export([start_child/4]).
-export([stop_child/1]).

%% ------------------------------------------------------------------
%% supervisor Function Exports
%% ------------------------------------------------------------------

-export([init/1]).

%% ------------------------------------------------------------------
%% Macro Definitions
%% ------------------------------------------------------------------

-define(SERVER, ?MODULE).
-define(CB_MODULE, ?MODULE).

%% ------------------------------------------------------------------
%% Type Definitions
%% ------------------------------------------------------------------

-type sup_flags() :: {one_for_one, 10, 5}.

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?CB_MODULE, []).

-spec start_child(atom(), http | filesystem, string(),
                  [locus_http_loader:opt() | locus_filesystem_loader:opt()])
        -> ok | {error, term()}.
start_child(DatabaseId, URLType, DatabaseURL, Opts) ->
    ChildSpec = child_spec(DatabaseId, URLType, DatabaseURL, Opts),
    case supervisor:start_child(?SERVER, ChildSpec) of
        {ok, _Pid} ->
            ok;
        {error, already_present} ->
            {error, already_started};
        {error, {already_started, _Pid}} ->
            {error, already_started};
        {error, {Error, _Child}} ->
            {error, Error}
    end.

-spec stop_child(atom()) -> ok | {error, not_found}.
stop_child(DatabaseId) ->
    ChildId = child_id(DatabaseId),
    case supervisor:terminate_child(?SERVER, ChildId) of
        ok ->
            case supervisor:delete_child(?SERVER, ChildId) of
                ok -> ok;
                {error, not_found} ->
                    {error, not_found}
            end;
        {error, not_found} ->
            {error, not_found}
    end.

%% ------------------------------------------------------------------
%% supervisor Function Definitions
%% ------------------------------------------------------------------

-spec init([]) -> {ok, {sup_flags(), []}}.
init([]) ->
    % TODO consider simple_one_for_one strategy with transient children
    SupFlags = {one_for_one, 10, 5},
    {ok, {SupFlags, []}}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

child_spec(DatabaseId, URLType, DatabaseURL, Opts) ->
    Args = [DatabaseId, DatabaseURL, Opts],
    Id = child_id(DatabaseId),
    Module = child_module(URLType),
    Start = {Module, start_link, Args},
    Restart = permanent,
    Shutdown = 5000,
    Type = worker,
    Modules = [Module],
    {Id, Start, Restart, Shutdown, Type, Modules}.

child_id(DatabaseId) ->
    % FIXME this is incorrect for filesystem URLs.
    % It was left like this so we wouldn't break interface.
    % Fix it the next time we do break interface.
    {http_loader, DatabaseId}.

child_module(http) -> locus_http_loader;
child_module(filesystem) -> locus_filesystem_loader.
