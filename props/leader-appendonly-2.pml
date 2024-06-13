ltl leaderAppendOnly01 {
    always (
        state[0] == leader implies (
            (log[0].log[1] == 0)
            || ((log[0].log[1] == 1) weakuntil (state[0] != leader))
            || ((log[0].log[1] == 2) weakuntil (state[0] != leader))
            || ((log[0].log[1] == 3) weakuntil (state[0] != leader))
        )
    )
}
