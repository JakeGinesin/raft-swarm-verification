Raft, formally verified using `spin`.

While Raft has been formally verified with both model checkers and theorem provers before, I wanted to have a clean and configurable model for research. 

# Setup
Requirements: 
- `spin 6.5.2`
- unix-based os (sorry windows users)

To verify the model against the defined properties (stored in `props`), run:
```
sh runner.sh
```
And, the results will be placed into `out`. In case you don't want to do this, the output for running the verification with 3 nodes was placed in `out-samp`

# A note about the properties
The properties were derived directly from the original Raft paper.

The properties are not defined to reason about all nodes - rather, they're defined over a subset of the nodes. This doesn't affect the completeness of the properties though. All the nodes are symmetric, and because the model checker explores all possible states, a violating trace on one subset of nodes is replicable across all other subsets of nodes of equal size.

# Todo
- [ ] get the model running with [spins](https://github.com/utwente-fmt/spins) and [swarm](https://www.spinroot.com/swarm/) instead of just running it raw
- [ ] full log completions
- [x] all props from paper
- [x] canonical election sequence

# References
- [Raft Paper](https://raft.github.io/raft.pdf)
- [Raft TLA+ Model](https://github.com/ongardie/raft.tla/blob/master/raft.tla)
