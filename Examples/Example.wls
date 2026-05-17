projectDirectory = ParentDirectory[$InputFileName//DirectoryName];

PacletDirectoryLoad[projectDirectory];
Needs["CoffeeLiqueur`Workshop`MarkovJunior`" -> "mj`"];

empty = GrayLevel[0];
yellow = RGBColor[1, 1, 0];
red = RGBColor[1, 0, 0];
river = RGBColor[1/3, 1/3, 1];
grass = RGBColor[0, 1, 0];
darkGrass = RGBColor[0, 2/3, 0];

riverRules = {
  (* Create two random seed points. *)
  {1, 1, {empty -> yellow}},
  {1, 1, {empty -> red}},

  (* Flood both seed regions randomly. *)
  {
    1,
    Infinity,
    {
      {a___, red, empty, b___} :> {a, red, red, b},
      {a___, yellow, empty, b___} :> {a, yellow, yellow, b}
    }
  },

  (* Mark the meeting edge as river. *)
  {
    All,
    Infinity,
    {
      {a___, red, yellow, b___} :> {a, river, river, b}
    }
  },

  (* Remove the temporary flood colors. *)
  {
    All,
    Infinity,
    {
      {a___, yellow, b___} :> {a, empty, b},
      {a___, red, b___} :> {a, empty, b}
    }
  },

  (* Expand the river once and fill diagonal gaps. *)
  {
    All,
    1,
    {
      {a___, river, empty, b___} :> {a, river, river, b}
    }
  },

  (* Place grass around the river, then fill the rest. *)
  {
    All,
    Infinity,
    {
      {a___, river, empty, b___} :> {a, grass, grass, b}
    }
  },
  {
    1,
    13,
    {
      {a___, empty, b___} :> {a, darkGrass, b}
    }
  },
  {
    1,
    Infinity,
    {
      {a___, darkGrass, empty, b___} :> {a, darkGrass, darkGrass, b},
      {a___, grass, empty, b___} :> {a, grass, grass, b}
    }
  }
};

initialState[size_: 40] := mj`MarkovState[
  ConstantArray[empty, {size, size}],
  riverRules
];

state = initialState[];
finalState = NestWhile[mj`Propagate, state, Not @* mj`FinishedQ];
outputPath = FileNameJoin[{$InputFileName//DirectoryName, "markov-river.png"}];

Export[
  outputPath,
  ArrayPlot[mj`GetArray[finalState], PixelConstrained -> 12]
];

Print["Wrote ", outputPath];
