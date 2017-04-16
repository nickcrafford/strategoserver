% @author Nick Crafford <nick@webdevengines.com>
% @copyright 2011 Nick Crafford.

-module(strategoserver_http).
-author("Nick Crafford <nickcrafford@gmail.com>").
-export([handle_request/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Handle a request... Use serve_request to do the actual work
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
handle_request(Req) ->  
  Post          = Req:parse_post(),
  Get           = Req:parse_qs(),  
  Method        = Req:get(method),
  Path          = web_util:trimSlashes(Req:get(path)),
  {ok,PathList} = httpd_util:split(Path,"/",20),
  serve_request(Req, PathList, Get, Post, Method).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%% Web Services %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create a game
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req, ["rpc", "newGame"], _,
              [{"isPlayer1", TisPlayer1},
               {"playerEmail", PlayerEmail},
               {"opposingEmail", OpposingEmail}], 'POST') ->
  {IsPlayer1, _} = string:to_integer(TisPlayer1),
  Resp = strategoserver_services:createGame(IsPlayer1, PlayerEmail, OpposingEmail),
  Json = mochijson2:encode(Resp),  
  Req:respond({200, [{"Content-Type", "text/html"}], Json});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Start a Re-Match
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["rpc","rematch"], _,
              [{"gameId", GameId}], 'POST') ->
  Resp = strategoserver_services:rematch(GameId),
  Json = mochijson2:encode(Resp),
  Req:respond({200, [{"Content-Type", "text/html"}],Json});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get Messages
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["rpc","getMessages"],_,
              [{"gamePlayerId",       GamePlayerId},
               {"checksum",           Checksum}],
              'POST') ->
  % Validate Game Player
  GamePlayerIdExists = db_util:exists(game_players, GamePlayerId),
  if
    % Game Player is valid
    GamePlayerIdExists =:= true ->
     
      % Validate Game State
      StateOk = strategoserver_services:checkState(GamePlayerId, Checksum), 

      if
        % State is valid
        StateOk =:= true ->
          ok   = strategoserver_messages:setGamePlayerProcessId(GamePlayerId, self()),
          Resp = strategoserver_messages:getMessages(GamePlayerId),

          if
            length(Resp) =:= 0 ->
              receive you_have_messages ->
                Msgs = strategoserver_messages:getMessages(GamePlayerId)
              after 30000 ->
                Msgs = []
              end;
            true ->
              Msgs = Resp
          end;
        % State is invalid/out of sync
        true ->
          Msgs = [web_util:returnMsg(error, outOfSync, getMessages)]   
      end;
    % Game Player is not valid
    true ->
      Msgs = [web_util:returnMsg(error, invalidGamePlayerId, getMessages)]
  end,
  Json = mochijson2:encode(Msgs),
  Req:respond({200, [{"Content-Type", "text/html"}],Json});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set Board
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["rpc","setBoard"], _,
              [{"gameId",         GameId},
               {"gamePlayerId",   GamePlayerId},
               {"boardPositions", BoardPositionJson}],
              'POST') -> 
  BoardPositions = mochijson2:decode(BoardPositionJson),
  Resp           = strategoserver_services:setBoard(GameId, GamePlayerId, BoardPositions),
  Json           = mochijson2:encode(Resp),  
  Req:respond({200, [{"Content-Type", "text/html"}],Json});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make Move
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["rpc","makeMove"],_,
              [{"gameId",             GameId},
               {"gamePlayerId",       GamePlayerId},
               {"sx",                 Sx},
               {"sy",                 Sy},
               {"tx",                 Tx},
               {"ty",                 Ty},
               {"checksum",           Checksum}],
              'POST') ->
  StateOk = strategoserver_services:checkState(GamePlayerId, Checksum), 
  
  if
    StateOk =:= true ->
      {CSx,_}  = string:to_integer(Sx),
      {CSy,_}  = string:to_integer(Sy),
      {CTx,_}  = string:to_integer(Tx),
      {CTy,_}  = string:to_integer(Ty),
      Resp     = strategoserver_services:makeMove(GameId, GamePlayerId,CSx,CSy,CTx,CTy);
    true ->
      Resp = web_util:returnMsg(error, outOfSync, makeMove)
  end,

  Json = mochijson2:encode(Resp),
  Req:respond({200, [{"Content-Type", "text/html"}],Json});

% Game board
serve_request(Req,["rpc","getBoard"],_,
              [{"gameId",       GameId}, 
               {"gamePlayerId", GamePlayerId}],
              'POST') ->
  GameExists       = db_util:exists(games, GameId),
  GamePlayerExists = db_util:exists(game_players, GamePlayerId),
  
  if
    GameExists =:= true andalso GamePlayerExists =:= true ->  
      Resp = strategoserver_services:getGameBoard(GameId, GamePlayerId);
    true ->
      Resp = web_util:returnMsg(error, invalidCriteria ,getGameBoard)
  end,
  
  Json = mochijson2:encode(Resp),  
  Req:respond({200, [{"Content-Type", "text/html"}], Json});  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Templates %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Game created
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["game-created"],_,_,'GET') ->
  web_util:respondWithTemplate(Req, "gameCreated.html",
                               game_created_template,
                               "Game Created!",
                               [], 200);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Game board
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["board",GameId, GamePlayerId],_,_,'GET') ->
  web_util:respondWithTemplate(Req, "board.html",
                               game_board_template, 
                               "Strategolobby: Game On!",
                               [{gameId, GameId},{gamePlayerId,GamePlayerId}, 
                                {isBoardPage,true}], 200);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                               
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Static Files %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Serve images
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["media","images",Filename],_,_,'GET') ->
  Req:serve_file(Filename, "static/images/");
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Serve JS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["js",Filename],_,_,'GET') ->
  Req:serve_file(Filename, "static/js/");
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Serve CSS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,["css",Filename],_,_,'GET') ->
  Req:serve_file(Filename, "static/css/");
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 404 -> Not found...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
serve_request(Req,_,_,_,_) ->
    web_util:respondWithTemplate(Req, "404.html",
                                 fourofour_template, 
                                 "StrategoLobby: 404",
                                 [], 
                                 404).
