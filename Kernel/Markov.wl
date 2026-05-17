BeginPackage["CoffeeLiqueur`Workshop`MarkovJunior`"]

MarkovState::usage = "MarkovState[initialArray, rules] creates MarkovState from `initialArray` and a set of provided rules/instructions `rules`";

Propagate::usage = "Propagate[m_MarkovState] does a single step in evaluation of `m` and returns a new state";
GetArray::usage = "GetArray[m_MarkovState] gets array field from the current `m` state";
FinishedQ::usage = "FinishedQ[m_MarkovState] checks if the evaluation is finished and no more rules can be applied";


Begin["`Private`"]

(* Supporting cast *)
(* just to make API nicer *)

MarkovState;

GetArray[ MarkovState[field_List, _Association, 2] ] := field;
FinishedQ[ MarkovState[_List, a_Association, 2] ] := a["ruleNumber"] > Length[ a["rules"] ]

MarkovState /: MakeBoxes[MarkovState[field_List, props_Association, 2], StandardForm ] := Module[{above},
        above = { 
          {BoxForm`SummaryItem[{"Rules: ", Length[ props["rules"] ]}]},
          {BoxForm`SummaryItem[{"Active rule: ", props["ruleNumber"]}]},
          {BoxForm`SummaryItem[{"Step: ", props["step"]}]},
          {BoxForm`SummaryItem[{"Finished: ", props["ruleNumber"] > Length[ props["rules"] ] }]} 
        };

        BoxForm`ArrangeSummaryBox[
           MarkovState,
           MarkovState[field, props, 2],
           ArrayPlot[field, ImageSize->40],
           above,
           Null
        ]
]  

MarkovState::wfield = "Field argument is not a list"
MarkovState::malrl  = "Malformed rules"
MarkovState::field3 = "3D field arrays are not supported yet"
MarkovState::unknw  = "Unknown input field shape"

MarkovState[field_, rules_] := Which[
  !ListQ[field],
    Message[MarkovState::wfield];
    $Failed,
  
  !MatchQ[rules, {{1|All, _Integer|Infinity, Rule | RuleDelayed | {__Rule | __RuleDelayed}}..}],
    Message[MarkovState::malrl];
    $Failed,
  
  MatchQ[field, {{{__}..}..}],
    Message[MarkovState::field3];
    $Failed,
  
  MatchQ[field, {{__}..}],
    MarkovState[
      field,
      <|
          "rules" -> (correctRules/@rules),
          "ruleNumber" -> 1,
          "step" -> 0
      |>,
      2
    ],

  True,
    Message[MarkovState::unknw];
    $Failed
];

Propagate[s:MarkovState[_List, _Association, 2] ] := With[{res = applyRules@@s},
  MarkovState @@ res 
];

Propagate::mlst = "Malformed state"

Propagate[s:MarkovState[_, _, ___] ] := With[{},
  Message[Propagate::mlst]
  $Failed
];

(* Main MarkovJunior engine implementation *)
(* this takes input field, state and makes 1 step *)
(* and returns new field and a new state *)

applyRules[input_, state_, _] := With[{
  ruleNumber = state["ruleNumber"]
}, If[ruleNumber <= Length[state["rules"]], With[{
  rl = state["rules"][[ruleNumber]],
  step = state["step"]
}, Switch[rl[[1]],
  1,
    Module[{variants},
      variants = Join@@MapThread[
        Map[#2, ReplaceList[rl[[3]] ][#1[input]] ] &,
        ops
      ];
      
      If[Length[variants]==0, Return[{
        input, Join[state, <|"step"->0, "ruleNumber"->ruleNumber+1|>], 2
      }]];

      {
        RandomChoice[variants], 
        Join[state, If[step < rl[[2]]-1,
            <|"step"->step+1|>,
            <|"step"->0, "ruleNumber"->ruleNumber+1|>
          ]
        ], 2
      }
    ],

  All, Module[{},
    With[{transformed = Fold[
      #2[[2]][ReplaceAll[#2[[1]][#1], rl[[3]]]] &,
      input,
      tops
    ]},
    
      If[transformed === input, Return[{
          input, Join[state, <|"step"->0, "ruleNumber"->ruleNumber+1|>], 2
      }] ];

      {
        transformed,
        Join[state, If[step < rl[[2]]-1,
            <|"step"->step+1|>,
            <|"step"->0, "ruleNumber"->ruleNumber+1|>
        ] ], 2
      }
    ] ]
] ], {input, state, 2}] ]


(* Symmetry operations used for the field *)
(* otherwise rules can't be generalized for all directions *)

rot[0][m_] := m;
rot[1][m_] := Transpose[Reverse[m]];
rot[2][m_] := Reverse[Reverse /@ m];
rot[3][m_] := Reverse[Transpose[m]];

mirror[m_] := Reverse /@ m;  (* left-right mirror *)

symmetries = Join[
   Table[rot[k], {k, 0, 3}],
   Table[rot[k] @* mirror, {k, 0, 3}]
];

inverseSymmetries = Join[
   Table[rot[Mod[-k, 4]], {k, 0, 3}],
   Table[mirror @* rot[Mod[-k, 4]], {k, 0, 3}]
];

ops = {symmetries, inverseSymmetries};
tops = Transpose[ops];

(* Rules transformation to compensate for the absence of ReplaceAllList feature *)
(* this one checks is this is 0D or 1D rule and levels it up to 2D *)
(* you do not need this if you write rules for (1) in the full 2D form *)

levelUp[0][expr_] := expr;
levelUp[1][expr_] := Module[{lr, rl}, expr /. {
  RuleDelayed[a_, Verbatim[Condition][b_, c_]] :> RuleDelayed[{lr___, a, rl___}, Condition[{lr, b, rl}, c]],
  RuleDelayed[a_, b_] :> RuleDelayed[{lr___, a, rl___}, {lr, b, rl}]
}]

levelUp[2][expr_] := Module[{lr, rl, af, bf}, expr /. {
  Rule[a_, Verbatim[Condition][b_, c_]] :> RuleDelayed[{lr___, {af___, a, bf___}, rl___}, Condition[{lr, {af, b, bf}, rl}, c]],
  Rule[a_, b_] :> RuleDelayed[{lr___, {af___, a, bf___}, rl___}, {lr, {af, b, bf}, rl}],  
  RuleDelayed[a_, Verbatim[Condition][b_, c_]] :> RuleDelayed[{lr___, {af___, a, bf___}, rl___}, Condition[{lr, {af, b, bf}, rl}, c]],
  RuleDelayed[a_, b_] :> RuleDelayed[{lr___, {af___, a, bf___}, rl___}, {lr, {af, b, bf}, rl}]
}]

correctRules[rl : {All, _, _}] := rl;
correctRules[rl : {1  , n_, rule_Rule}] := {1, n, levelUp@rule}
correctRules[rl : {1  , n_, rules_List}] := {1, n, levelUp/@rules}

levelUp[testRl_Rule | testRl_RuleDelayed] := Which[
  MatchQ[testRl[[1]], {___, List[__], ___}], 
    testRl,
  MatchQ[testRl[[1]], {___, expr_, ___}], 
    levelUp[1][testRl],
  True, 
    levelUp[2][testRl]
]

End[]
EndPackage[]