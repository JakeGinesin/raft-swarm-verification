#define MAX_TERM 3 // 1 to 3
#define MAX_LOG 2 // 0 to 1
#define NUM_SERVERS 3 // 2 to n

#define NIL 20 // a number that won't be used

// message channels
typedef AppendEntry {
    byte term, leaderCommit, index, prevLogTerm, src
};
typedef AppendEntryChannels {
    chan ch = [NUM_SERVERS] of { AppendEntry };
};
AppendEntryChannels ae_ch[NUM_SERVERS];

typedef AppendEntryResponse {
    byte term;
    byte src;
    bool success
};
typedef AppendEntryResponseChannels {
    chan ch = [NUM_SERVERS] of { AppendEntryResponse };
};
AppendEntryResponseChannels aer_ch[NUM_SERVERS];

typedef RequestVote {
    byte term;
    byte lastLogIndex;
    byte lastLogTerm; 
    byte src
};
typedef RequestVoteChannels {
    chan ch = [NUM_SERVERS] of { RequestVote };
};
RequestVoteChannels rv_ch[NUM_SERVERS];

typedef RequestVoteResponse {
    byte term;
    byte src;
    bool voteGranted
};
typedef RequestVoteResponseChannels {
    chan ch = [NUM_SERVERS] of { RequestVoteResponse };
};
RequestVoteResponseChannels rvr_ch[NUM_SERVERS];

// LTL-relevant terms
mtype:State = { leader, candidate, follower };
mtype:State state[NUM_SERVERS];
byte currentTerm[NUM_SERVERS];
typedef Logs {
    byte log[2];
};
Logs log[NUM_SERVERS];
byte commitIndex[NUM_SERVERS];

proctype server(byte serverId) {
    state[serverId] = follower;
    byte votedFor = NIL;
    
    byte i;
    byte j;
    byte num_votes = 0; // for state space efficiency, we don't store each peer's vote in an array - we just store the total.

    RequestVote rv;
    byte lastLogTerm, lastLogIndex;
    RequestVoteResponse rvr;
    bool logOk;

    byte votes_threshhold = (NUM_SERVERS >> 1) + 1;

    AppendEntry ae;
    AppendEntryResponse aer;

    do // main loop
    :: // timeout
        (state[serverId] == candidate || state[serverId] == follower) ->
            atomic {
                state[serverId] = candidate;
                currentTerm[serverId] = currentTerm[serverId] + 1;

                if // end if defined limit is reached
                :: (currentTerm[serverId] <= MAX_TERM) -> skip
                fi

                votedFor = serverId;
                num_votes = 1; // node votes for itself
            }
    :: // restart
        state[serverId] = follower
    :: // request vote
        (state[serverId] == candidate) ->
            atomic {
                rv.term = currentTerm[serverId];
                rv.src = serverId;

                // log update 
                if
                :: (log[serverId].log[0] == 0) ->
                    rv.lastLogTerm = 0;
                    rv.lastLogIndex = 0
                :: (log[serverId].log[0] != 0 && log[serverId].log[1] == 0) ->
                    rv.lastLogTerm = log[serverId].log[0];
                    rv.lastLogIndex = 1
                :: (log[serverId].log[0] != 0 && log[serverId].log[1] != 0) ->
                    rv.lastLogTerm = log[serverId].log[1];
                    rv.lastLogIndex = 2
                fi

                for (j : 0 .. NUM_SERVERS) {
                  if 
                  :: serverId != j ->
                    rv_ch[j].ch!rv
                  fi
                }
            }
    :: // become leader
      (num_votes >= votes_threshhold) -> state[serverId] = leader;
    :: // handle RequestVote
        (rv_ch[serverId].ch?[rv]) -> 
            atomic {
                rv_ch[serverId].ch?rv;
                i = rv.src;
                assert(i != serverId);
                // update terms
                if
                :: (rv.term > currentTerm[serverId]) ->
                    currentTerm[serverId] = rv.term;
                    state[serverId] = follower;
                    votedFor = NIL
                :: (rv.term <= currentTerm[serverId]) ->
                    skip
                fi

                if
                :: (log[serverId].log[0] == 0) ->
                    lastLogTerm = 0;
                    lastLogIndex = 0
                :: (log[serverId].log[0] != 0 && log[serverId].log[1] == 0) ->
                    lastLogTerm = log[serverId].log[0];
                    lastLogIndex = 1
                :: (log[serverId].log[0] != 0 && log[serverId].log[1] != 0) ->
                    lastLogTerm = log[serverId].log[1];
                    lastLogIndex = 2
                fi

                logOk = rv.lastLogTerm > lastLogTerm || rv.lastLogTerm == lastLogTerm && rv.lastLogIndex >= lastLogIndex;
                rvr.voteGranted = rv.term == currentTerm[serverId] && logOk && (votedFor == NIL || votedFor == i);

                rvr.term = currentTerm[serverId];
                rvr.src = serverId;
                if
                :: rvr.voteGranted -> votedFor = i
                :: !rvr.voteGranted -> skip
                fi
                rvr_ch[i].ch!rvr;
            }
    :: // handle RequestVoteResponse
        (rvr_ch[serverId].ch?[rvr]) -> 
            atomic {
                rvr_ch[serverId].ch?rvr;
                i = rvr.src;
                assert(i != serverId);

                if
                :: (rvr.term > currentTerm[serverId]) -> // update terms
                    currentTerm[serverId] = rvr.term;
                    state[serverId] = follower;
                    votedFor = NIL
                :: (rvr.term == currentTerm[serverId] && rvr.voteGranted) -> num_votes++;
                :: (!(rvr.term > currentTerm[serverId]) && 
                   !(rvr.term == currentTerm[serverId] && 
                     rvr.voteGranted)) -> skip;
                fi
            }

    :: // append entries
        (state[serverId] == leader) ->
            atomic {
                ae.term = currentTerm[serverId];
                ae.leaderCommit = commitIndex[serverId];
                ae.src = serverId;
                if
                :: (log[serverId].log[0] != log[i].log[0]) -> ae.index = 0
                :: (log[serverId].log[1] != 0 && 
                    log[serverId].log[0] == log[i].log[0] && 
                    log[serverId].log[1] != log[i].log[1]) ->
                    ae.index = 1
                    ae.prevLogTerm = log[i].log[0]
                :: ae.index = NIL
                fi
                byte index = 0;
                do
                :: index == NUM_SERVERS-1 -> break;
                :: index < NUM_SERVERS-1 -> index++;
                :: break;
                od

                ae_ch[index].ch!ae;
            }
    :: // handle AppendEntry
        (ae_ch[serverId].ch?[ae]) -> 
            atomic {
                ae_ch[serverId].ch?ae;
                i = ae.src;
                assert(i != serverId);

                // update terms
                if
                :: (ae.term > currentTerm[serverId]) ->
                    currentTerm[serverId] = ae.term;
                    state[serverId] = follower;
                    votedFor = NIL
                :: (ae.term <= currentTerm[serverId]) -> skip;
                fi
                assert(ae.term <= currentTerm[serverId]);

                if
                :: (ae.term == currentTerm[serverId] && state[serverId] == candidate) ->
                    state[serverId] = follower;
                    votedFor = NIL
                :: (ae.term != currentTerm[serverId] || state[serverId] != candidate) ->
                    skip
                fi
                assert(!(ae.term == currentTerm[serverId]) || (state[serverId] == follower));
                
                // ripped from paper
                logOk = ae.index == 0 || (ae.index == 1 && ae.prevLogTerm == log[serverId].log[0]);
                aer.src = serverId;
                aer.term = currentTerm[serverId];
                if
                :: (ae.term < currentTerm[i] || ae.term == currentTerm[serverId] && state[serverId] == follower && !logOk) -> // reject request
                    aer.success = 0;
                    aer_ch[i].ch!aer
                :: (ae.term == currentTerm[serverId] && state[serverId] == follower && logOk) ->
                    aer.success = 1;

                    log[serverId].log[ae.index] = ae.term;

                    // assignment is admissable b/c max log is hard-coded and small (2)
                    // leaderCommit = 0 => server commit index must be 0
                    // leaderCommit = 1 => server commit index *can* be 0
                    // TODO: find a way to generalize across log size
                    commitIndex[serverId] = ae.leaderCommit;

                    aer_ch[i].ch!aer
                fi
            }
    :: // handle AppendEntryResponse
        (aer_ch[serverId].ch ? [aer]) -> 
            atomic {
                aer_ch[serverId].ch ? aer;
                i = aer.src;
                assert(i != serverId);

                if
                :: (aer.term > currentTerm[serverId]) -> // update terms
                    currentTerm[serverId] = aer.term;
                    state[serverId] = follower;
                    votedFor = NIL
                :: (aer.term < currentTerm[serverId]) ->
                    skip
                // advance commit index
                :: (aer.term == currentTerm[serverId] && aer.success && state[serverId] == leader) ->
  
                    // this is a little tricky
                    // TODO: improve this for arbitrary log size
                    if // end if commitIndex reaches the limit
                    :: (commitIndex[serverId] == 0 && log[i].log[0] == log[serverId].log[0]) ->
                        commitIndex[serverId] = 1
                    // don't skip if commitIndex[serverId] should be 2
                    :: (commitIndex[serverId] == 1 && !(log[serverId].log[1] != 0 && log[i].log[1] == log[serverId].log[1])) ->
                        skip; // case shouldn't be reached (i think)
                    fi
                :: (aer.term == currentTerm[serverId] && !(aer.success && state[serverId] == leader)) ->
                    skip
                fi
            }
    :: // client request
        (state[serverId] == leader && log[serverId].log[1] == 0) ->
            /// hard coded. TODO: find efficient impl for arbitrary log size
            if
            :: log[serverId].log[0] == 0 ->
                log[serverId].log[0] = currentTerm[serverId]
            :: log[serverId].log[0] != 0 ->
                log[serverId].log[1] = currentTerm[serverId]
            fi 
    od // end main loop
};

init {
    int k;
    for (k : 0 .. NUM_SERVERS - 1) {
      run server(k);
    }
}
