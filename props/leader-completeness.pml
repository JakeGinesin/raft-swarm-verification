ltl leaderCompleteness {
    always (
        (
            (commitIndex[0] == 1) implies
                always (
                    ((state[1] == leader) implies (log[0].log[0] == log[1].log[0]))
                    && ((state[2] == leader) implies (log[0].log[0] == log[2].log[0]))
                )
        ) 
    )
}
