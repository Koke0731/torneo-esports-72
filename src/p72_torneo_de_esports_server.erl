%% -*- mode: erlang -*-
%% Compatibilidad con la interfaz base del proyecto #72.
%%
%% El repositorio de la clase (tectijuana/logicfun-proyectos) expone un
%% gen_server minimo con ping/0 y state/0 que sus pruebas de plantilla
%% invocan. Este modulo conserva esa interfaz para que dichas pruebas
%% sigan siendo validas sobre la implementacion completa.
-module(p72_torneo_de_esports_server).
-behaviour(gen_server).

-export([start_link/0, ping/0, state/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

ping() ->
    gen_server:call(?MODULE, ping).

state() ->
    gen_server:call(?MODULE, state).

init([]) ->
    logger:info("~s iniciado", [?MODULE], #{proyecto => p72_torneo_de_esports}),
    {ok, #{iniciado_en => erlang:system_time(second)}}.

handle_call(ping, _From, State) ->
    {reply, pong, State};
handle_call(state, _From, State) ->
    {reply, State, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
