ltl logMatching {
    always (
        ((log[0].log[1] != 0 && log[0].log[1] == log[1].log[1])
            implies (log[0].log[0] == log[1].log[0]))
        && ((log[0].log[1] != 0 && log[0].log[1] == log[2].log[1])
            implies (log[0].log[0] == log[2].log[0]))
        && ((log[1].log[1] != 0 && log[1].log[1] == log[2].log[1])
            implies (log[1].log[0] == log[2].log[0]))
    )
}
