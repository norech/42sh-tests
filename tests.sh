#!/bin/bash

# REPOSITORY: https://github.com/norech/42sh-tests

## Available commands:

## expect_stdout_match <command>  : Command will be executed on both mysh
##                                  and tcsh and stdout must match

## expect_stderr_match <command>  : Command will be executed on both mysh
##                                  and tcsh and stderr must match

## expect_env_match <command>     : Command will be executed on both mysh
##                                  and tcsh and environment variables must match

## expect_pwd_match <command>     : Command will be executed on both mysh
##                                  and tcsh and their PWD environment variables
##                                  must match

## expect_stdout_equals <command> : Command will be executed on both mysh
##                                  and tcsh and stdout must match

## expect_stdout_equals <command> <value> : Command will be executed on mysh
##                                          and its stdout must be equal to value

## expect_stderr_equals <command> <value> : Command will be executed on mysh
##                                          and its stderr must be equal to value

## expect_exit_code <command> <code> : Command will be executed on mysh
##                                     and its exit code must be equal to code

## expect_signal_message_match <sig> : Signal will be sent to child process
##                                     and stderr must be equal to the tcsh one


## Each command can be prefixed by:

## WITH_ENV="KEY=value KEY2=value2" : Specify which environment variables
##                                    must be passed to mysh using `env` command.
##                                    Not recommended with *_match commands.
##                                    WITH_ENV="-i" is equivalent to `env -i ./mysh`.

## WITHOUT_COREDUMP=1 : When value is 1, disable core dump.

tests()
{


    # EXECUTE COMMANDS
    expect_stdout_match "ls"
    expect_stdout_match "/bin/ls" # full path
    expect_stdout_match "/bin/ls -a" # full path with args
    expect_stdout_match "ls -a"
    expect_stderr_match "egegrgrgegergre" # not existing binary
    expect_stderr_match "uyiuoijuuyyiy" # not existing binary 2

    WITH_ENV="PATH=" \
    expect_stderr_equals "ls" "ls: Command not found." # no PATH to be found


    # EXECUTE COMMANDS - relative paths
    if [ -t 0 ]; then # if is a tty, avoids recursion problems
        expect_stdout_match "./$(basename "$0") --helloworld" # ./tests.sh --helloworld
        expect_stdout_match "../$(basename $PWD)/$(basename "$0") --helloworld" # ../parentdir/tests.sh --helloworld
    fi

    # FORMATTING & SPACING
    expect_stdout_match " ls -a"
    expect_stdout_match " ls  -a"
    expect_stdout_match $'     ls\t\t -a'
    expect_stdout_match $'     ls\t\t -a\t'
    expect_stdout_match $'ls -a\t'
    expect_stdout_match $'ls \t-a\t'
    expect_stdout_match $'ls\t-a'
    expect_stdout_match $'\tls -a\t'

    # SETENV
    expect_env_match "setenv A b"
    expect_env_match "setenv _A b"
    expect_env_match "setenv AB0 b"
    expect_env_match "setenv A_B0 b"
    expect_env_match "setenv A_C b"
    expect_env_match "setenv A"   # variables can be set with one argument
    expect_env_match "setenv"

    expect_stderr_match "setenv -A b" # variables must start with a letter
    expect_stderr_match "setenv 0A b" # variables must start with a letter
    expect_stderr_match "setenv A- b" # variables must be alphanumeric
    expect_stderr_match "setenv A b c" # setenv must contain 1 or 2 arguments

    # ENV
    expect_env_match "env"

    WITH_ENV="-i" \
    expect_exit_code "env" 0

    # EXIT
    expect_exit_code "" 0 # no command executed
    expect_exit_code "exit" 0
    expect_exit_code "exit 24" 24
    expect_exit_code "exit 18" 18

    # CD
    expect_stderr_match "cd -"     # previous env was not set
    expect_stderr_match "cd /root" # no permissions to access folder error
    expect_stderr_match "cd /htyg/grrggfghfgdhgfghg" # folder not found error

    expect_pwd_match "cd ~"
    expect_pwd_match "cd /"
    expect_pwd_match $'cd /\ncd -' # change path then go back to last path => cd -
    expect_pwd_match "unsetenv PWD"
    expect_pwd_match "setenv PWD /home"

    # SIGNALS
    expect_signal_message_match SIGSEGV
    expect_signal_message_match SIGFPE
    expect_signal_message_match SIGBUS
    expect_signal_message_match SIGABRT

    WITHOUT_COREDUMP=1 \
    expect_signal_message_match SIGSEGV

    WITHOUT_COREDUMP=1 \
    expect_signal_message_match SIGFPE

    WITHOUT_COREDUMP=1 \
    expect_signal_message_match SIGBUS

    WITHOUT_COREDUMP=1 \
    expect_signal_message_match SIGABRT

}








#------------------------------------------------------------------------------------
# Here be dragons
#------------------------------------------------------------------------------------

if [[ $1 == "--helloworld" ]]; then
    echo "Hello world!"
    exit 42
fi

if ! which tcsh >/dev/null; then
    echo "Run: dnf install tcsh"
    exit 84
fi

if [[ ! -f "./mysh" ]]; then
    echo "./mysh not found"
    exit 84
fi

# do not load any starting script
# fixes `builin: not found` errors with proprietary drivers
alias tcsh="tcsh -f"

PASSED=""
FAILED=""

pass()
{
    echo "Passed"
    PASSED+=1
}

fail()
{
    echo "Failed: $@"
    FAILED+=1
}

expect_exit_code()
{
    echo ""
    echo ""
    echo "$1"
    echo "-----"
    echo "Expectation: Exit code must be $2"
    echo "---"
    EXIT1=$2

    echo "$1" | env $WITH_ENV ./mysh 2>&1
    EXIT2=$?

    if [[ $EXIT1 != $EXIT2 ]]; then
        fail "Exit code are different (expected $EXIT1, got $EXIT2)."
        return
    fi
    pass
}

expect_signal_message_match()
{
    local without_core_dump="$WITHOUT_COREDUMP"
    local signal_id="$(get_signal_id $1)"

    if [[ -z $without_core_dump ]]; then
        without_core_dump=0
    fi

    echo ""
    echo ""
    echo "SIGNAL: $1"
    if [[ "$without_core_dump" == "1" ]]; then
        echo "Without core dump"
    fi
    echo "-----"
    echo "Expectation: When executed program send a $1 signal ($signal_id), mysh stderr must match with tcsh"
    echo "---"


    if [[ ! -f /tmp/__minishell_segv ]]; then
        build_signal_sender
    fi

    TCSH_OUTPUT=$(echo "/tmp/__minishell_segv $without_core_dump $signal_id" | tcsh 2>&1 1>/dev/null)
    EXIT1=0 # apparently, marvin does not like 139 exit code, so we return 0

    MYSH_OUTPUT=$(echo "/tmp/__minishell_segv $without_core_dump $signal_id" | ./mysh 2>&1 1>/dev/null)
    EXIT2=$?

    DIFF=$(diff --color=always <(echo "$TCSH_OUTPUT") <(echo "$MYSH_OUTPUT"))
    if [[ $DIFF != "" ]]; then
        echo "< tcsh    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        return
    fi

    if [[ $EXIT1 != $EXIT2 ]]; then
        fail "Exit code are different (expected $EXIT1, got $EXIT2)."
        return
    fi
    pass
}

expect_pwd_match()
{
    echo ""
    echo ""
    echo "$@"
    echo "-----"
    echo "Expectation: PWD in environment variable must match with tcsh after the command"
    if [[ ! -z "$WITH_ENV" ]]; then
        echo "With environment variables: $WITH_ENV"
    fi
    echo "---"
    DIFF=$(diff --color=always <(echo "$@"$'\n'"env" | tcsh 2>&1 | grep "^PWD=") <(echo "$@"$'\n'"env" | env $WITH_ENV ./mysh 2>&1 | grep "^PWD="))
    if [[ $DIFF != "" ]]; then
        echo "< tcsh    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        return
    fi

    echo "$@" | tcsh 2>&1
    EXIT1=$?
    echo "$@" | env $WITH_ENV ./mysh 2>&1
    EXIT2=$?

    if [[ $EXIT1 != $EXIT2 ]]; then
        fail "Exit code are different (expected $EXIT1, got $EXIT2)."
        return
    fi
    pass
}

expect_env_match()
{
    SAMPLE_ENV="USER=$USER GROUP=$GROUP PWD=$PWD"
    echo ""
    echo ""
    echo "$@"
    echo "-----"
    echo "Expectation: Env must match with tcsh after the command"
    if [[ ! -z "$WITH_ENV" ]]; then
        echo "With environment variables: $WITH_ENV"
    fi
    echo "---"
    TCSH_OUTPUT="$(echo "$@"$'\n'"env" | env -i $SAMPLE_ENV tcsh 2>&1 | clean_env)"
    MYSH_OUTPUT="$(echo "$@"$'\n'"env" | env -i $SAMPLE_ENV $WITH_ENV ./mysh 2>&1 | clean_env)"
    DIFF=$(diff --color=always <(echo $TCSH_OUTPUT) <(echo $MYSH_OUTPUT))
    if [[ $DIFF != "" ]]; then
        echo "< tcsh    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        return
    fi

    echo "$@" | tcsh 2>&1 >/dev/null
    EXIT1=$?
    echo "$@" | env $WITH_ENV ./mysh 2>&1 >/dev/null
    EXIT2=$?

    if [[ $EXIT1 != $EXIT2 ]]; then
        fail "Exit code are different (expected $EXIT1, got $EXIT2)."
        return
    fi
    pass
}

expect_stdout_match()
{
    echo ""
    echo ""
    echo "$@"
    echo "-----"
    echo "Expectation: Command stdout must match with tcsh"
    if [[ ! -z "$WITH_ENV" ]]; then
        echo "With environment variables: $WITH_ENV"
    fi
    echo "---"
    DIFF=$(diff --color=always <(echo "$@" | tcsh 2>/dev/null) <(echo "$@" | env $WITH_ENV ./mysh 2>/dev/null))
    if [[ $DIFF != "" ]]; then
        echo "< tcsh    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        return
    fi

    echo "$@" | tcsh 2>&1 >/dev/null
    EXIT1=$?
    echo "$@" | env $WITH_ENV ./mysh 2>&1 >/dev/null
    EXIT2=$?

    if [[ $EXIT1 != $EXIT2 ]]; then
        fail "Exit code are different (expected $EXIT1, got $EXIT2)."
        return
    fi
    pass
}

expect_stdout_equals()
{
    echo ""
    echo ""
    echo "$1"
    echo "-----"
    echo "Expectation: Command stdout must equal '$2'"
    if [[ ! -z "$WITH_ENV" ]]; then
        echo "With environment variables: $WITH_ENV"
    fi
    echo "---"
    DIFF=$(diff --color=always <(echo "$2") <(echo "$(echo "$1" | env $WITH_ENV ./mysh 2>/dev/null)"))
    if [[ $DIFF != "" ]]; then
        echo "< expect    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        return
    fi
    pass
}

expect_stderr_match()
{
    echo ""
    echo ""
    echo "$@"
    echo "-----"
    echo "Expectation: Command stderr must match with tcsh"
    if [[ ! -z "$WITH_ENV" ]]; then
        echo "With environment variables: $WITH_ENV"
    fi
    echo "---"
    DIFF=$(diff --color=always <(echo "$(echo "$@" | tcsh 2>&1 >/dev/null)") <(echo "$(echo "$@" | env $ENV_VAR ./mysh 2>&1 >/dev/null)"))
    if [[ $DIFF != "" ]]; then
        echo "< tcsh    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        return
    fi

    echo "$@" | tcsh &>/dev/null
    EXIT1=$?
    echo "$@" | env $WITH_ENV ./mysh &>/dev/null
    EXIT2=$?

    if [[ $EXIT1 != $EXIT2 ]]; then
        fail "Exit code are different (expected $EXIT1, got $EXIT2)."
        return
    fi
    pass
}

expect_stderr_equals()
{
    echo ""
    echo ""
    echo "$1"
    echo "-----"
    echo "Expectation: Command stderr must equal '$2'"
    if [[ ! -z "$WITH_ENV" ]]; then
        echo "With environment variables: $WITH_ENV"
    fi
    echo "---"
    DIFF=$(diff --color=always <(echo "$2") <(echo "$(echo "$1" | env $WITH_ENV ./mysh 2>&1 >/dev/null)"))
    if [[ $DIFF != "" ]]; then
        echo "< expect    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        return
    fi
    pass
}

clean_env()
{
    grep -v -e "^SHLVL=" \
            -e "^HOSTTYPE=" \
            -e "^VENDOR=" \
            -e "^OSTYPE=" \
            -e "^MACHTYPE=" \
            -e "^LOGNAME=" \
            -e "^HOST=" \
            -e "^GROUP=" \
            -e "^_="
}

get_signal_id()
{
    trap -l | sed -nr 's/.*\b([0-9]+)\) '$1'.*/\1/p'
}

build_signal_sender()
{
    cat <<EOF >/tmp/__minishell_segv_code.c
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <sys/prctl.h>
#include <sys/types.h>

int main(int argc, char **argv)
{
    if (argc != 3)
        return (84);
    prctl(PR_SET_DUMPABLE, atoi(argv[1]) == 0);
    kill(getpid(), atoi(argv[2]));
    while (1);
}
EOF

    gcc -o /tmp/__minishell_segv /tmp/__minishell_segv_code.c
}

cleanup()
{
    pkill -P $$
    rm /tmp/__minishell_*
    exit
}

total() {
    echo ""
    echo ""
    echo "Tests passed: $(echo -n $PASSED | wc -m). Tests failed: $(echo -n $FAILED | wc -m)."
}

trap cleanup 2

tests
total
cleanup