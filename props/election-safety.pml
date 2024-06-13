ltl electionSafety {
    always !(
        (state[0] == leader && state[1] == leader && currentTerm[0] == currentTerm[1])
    )
}
