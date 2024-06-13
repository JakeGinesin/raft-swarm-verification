ltl stateMachineSafety {
    always (
        ((commitIndex[0] == 1 && commitIndex[1] == 1) implies (log[0].log[0] == log[1].log[0]))
    )
}
