ltl leaderAppendOnly00 {
    always (
        state[0] == leader implies (
            (log[0].log[0] == 0)
            || ((log[0].log[0] == 1) weakuntil (state[0] != leader))
            || ((log[0].log[0] == 2) weakuntil (state[0] != leader))
            || ((log[0].log[0] == 3) weakuntil (state[0] != leader))
        )
    )
}
