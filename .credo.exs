%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Refactor.Nesting, false},
        {Credo.Check.Refactor.MatchInCondition, false},
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        {Credo.Check.Refactor.UnlessWithElse, false},
        {Credo.Check.Refactor.NegatedConditionsWithElse, false},
        {Credo.Check.Refactor.CondStatements, false},
        {Credo.Check.Refactor.FunctionArity, max_arity: 10}
      ]
    }
  ]
}
