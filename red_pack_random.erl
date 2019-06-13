-module (red_pack_random).
-compile (export_all).
-define (IIF(A, B, C), (case A of true -> B; false->C end)).
-define (TolerantCoeff, 1.05).
-define (ControlRate, 0.8).

wechat(Total, Amount) ->
	wechat(Total, Amount, []).
wechat(Total, 0, L) -> 
	[H|T] = L,
	K = erlang:round((H + Total) * 100) / 100,
	[K|T];
wechat(Total, Amount, L) ->
	X = rand:uniform(),
	UpperT = Total / Amount * 2.0,	
	Lower = 0.01,
	Upper = ?IIF(UpperT > Lower, UpperT, Lower),
	N = (Upper - Lower) * X + Lower,
	Num = erlang:trunc(N * 100) / 100, 
	wechat(Total - Num, Amount - 1, [Num|L]).


random(Total, Amount, Upper, Lower) ->
	Var = make_var(Total, Amount, Upper, Lower),
	Mean = Total / Amount,
	L = red_pack_random:random(Total, Amount, Mean, Upper, Lower, Var, 1),
	case is_list(L) of
		true ->
			io:format("~w~nSum : ~p  Num : ~p  Max : ~p  Min : ~p~n",
				[L, lists:foldl(fun(X, Acc) -> X + Acc end, 0, L), length(L), lists:max(L), lists:min(L)]);
		_ ->
			L
	end.
random(Total, 1, Mean, Upper, Lower, Var, Method) ->
	[Total];
random(Total, Amount, Mean, Upper, Lower, Var, Method) ->
	case is_valid_bound(Total, Amount, Upper, Lower) of
		true ->
			NowMean = Total / Amount,
			OffsetRate = NowMean / Mean,
			SaveLowerT = Total - Upper * (Amount - 1),
			SaveLowerT2 = ?IIF(SaveLowerT > Lower, SaveLowerT, Lower),			
			SaveUpperT = Total - Lower * (Amount - 1),
			SaveUpperT2 = ?IIF(SaveUpperT < Upper, SaveUpperT, Upper),
			{SaveUpper, SaveLower} = 
				case macro_control() of
					true ->
						?IIF(OffsetRate > 1, {SaveUpperT2, NowMean}, {NowMean, SaveLowerT2});
					false ->
						{SaveUpperT2, SaveLowerT2}
				end,
			Var2 = make_var(Total, Amount, SaveUpper, SaveLower),			
			NormalMean =
			case OffsetRate < 1 / ?TolerantCoeff of
				true -> % last Num too big
					SaveLower;
				false ->
					case OffsetRate > ?TolerantCoeff of
						true -> % last Num too small
							SaveUpper;
						false ->
							NowMean
					end
			end,
			case Method of
				1 ->
					N = erlang:trunc(rand:normal(NormalMean, Var2)),
					case N >= SaveLower andalso N =< SaveUpper of
						true ->
							[N | random(Total - N, Amount - 1, Mean, Upper, Lower, Var, Method)];
						_ -> % failed, try again
							random(Total, Amount, Mean, Upper, Lower, Var, Method)
					end;
				_ ->
					N = rand:uniform(SaveUpper - SaveLower + 1) + SaveLower - 1,			
					[N | random(Total - N, Amount - 1, Mean, Upper, Lower, Var, Method)]
			end;
		_ ->
			impossible_range
	end.


is_valid_bound(Total, Amount, Upper, Lower) ->
	case Upper >= Total / Amount andalso Lower =< Total / Amount of
		true -> true;
		_ -> false
	end.

make_var(Total, Amount, Upper, Lower) ->
	Mean = Total / Amount,
	LowRange = Mean - Lower,
	HighRange = Upper - Mean,
	RangeDelta = ?IIF(LowRange > HighRange, LowRange - HighRange, HighRange - LowRange),
	OffsetCoefficient = 
	case RangeDelta > 0.333333 * (Upper - Lower) of
		true ->
			case RangeDelta > 0.8333333 * (Upper - Lower) of
				true -> % mean too close to upper or lower
					0.15;
				false -> % mean close to upper or lower
					0.3
			end; 
		false -> % mean close to avg of upper and lower
			0.4 
	end,
	math:pow((Upper - Lower) * OffsetCoefficient, 2).


macro_control() ->
	rand:uniform() < ?ControlRate.