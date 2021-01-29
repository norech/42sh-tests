#!/bin/bash

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

## expect_signal_message <sig> <message> : Signal will be sent to child process
##                                         and stderr must be equal to the message


## Each command can be prefixed by:

## WITH_ENV="KEY=value KEY2=value2" : Specify which environment variables
##                                    must be passed to mysh using `env` command.
##                                    Not recommended with *_match commands.
##                                    WITH_ENV="-i" is equivalent to `env -i ./mysh`.

tests()
{


    # EXECUTE COMMANDS
    expect_stdout_match "ls"
    expect_stdout_match "/bin/ls" # full path
    expect_stdout_match "ls -a"

    WITH_ENV="PATH=" \
    expect_stderr_equals "ls" "ls: Command not found." # no PATH to be found

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
    expect_env_match "setenv AB0 b"
    expect_env_match "setenv A_B0 b"
    expect_env_match "setenv A_C b"
    expect_env_match "setenv A"   # variables can be set with one argument

    expect_stderr_match "setenv -A b" # variables must start with a letter
    expect_stderr_match "setenv 0A b" # variables must start with a letter
    expect_stderr_match "setenv A- b" # variables must be alphanumeric
    expect_stderr_match "setenv A b c" # setenv must contain 1 or 2 arguments

    # ENV
    expect_env_match "env"

    WITH_ENV="-i" \
    expect_stdout_equals "env" ""

    # EXIT
    expect_exit_code "exit" 0
    expect_exit_code "exit 24" 24
    expect_exit_code "exit 18" 18

    # CD
    expect_stderr_match "cd -"     # previous env was not set
    expect_stderr_match "cd /root" # no permissions to access folder error
    expect_stderr_match "cd /htyg/grrggfghfgdhgfghg" # folder not found error

    expect_pwd_match "cd /"
    expect_pwd_match $'cd /\ncd -' # change path then go back to last path => cd -
    expect_pwd_match "unsetenv PWD"
    expect_pwd_match "setenv PWD /home"

    # SIGNALS
    expect_signal_message SIGSEGV "Segmentation fault (core dumped)"
    expect_signal_message SIGFPE  "Floating exception (core dumped)"


}








#------------------------------------------------------------------------------------
# Here be dragons
#------------------------------------------------------------------------------------

if ! which tcsh >/dev/null; then
    echo "Run: dnf install tcsh"
    exit 84
fi

if [[ ! -f "./mysh" ]]; then
    echo "./mysh not found"
    exit 84
fi

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

    echo "$1" | ./mysh 2>&1
    EXIT2=$?

    if [[ $EXIT1 != $EXIT2 ]]; then
        fail "Exit code are different (expected $EXIT1, got $EXIT2)."
        return
    fi
    pass
}

expect_signal_message()
{
    echo ""
    echo ""
    echo "SIGNAL: $1"
    echo "-----"
    echo "Expectation: When executed program send a $1 signal, mysh must print '$2' in stderr"
    echo "---"

    echo "yes" | ./mysh 1>/dev/null 2>/tmp/__minishell_test.log &
    sleep 0.15
    killall -s $1 yes
    wait
    OUTPUT=$(cat /tmp/__minishell_test.log)

    DIFF=$(diff --color=always <(echo "$2") <(echo "$OUTPUT"))
    if [[ $DIFF != "" ]]; then
        echo "< expect    > mysh"
        echo
        echo "$DIFF"
        fail "Output are different."
        rm /tmp/__minishell_test.log
        return
    fi
    rm /tmp/__minishell_test.log
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
    SAMPLE_ENV="HOSTTYPE=x86_64-linux VENDOR=unknown OSTYPE=linux MACHTYPE=x86_64 LOGNAME=alexis USER=alexis GROUP=alexis HOST=fedora PWD=$PWD"
    echo ""
    echo ""
    echo "$@"
    echo "-----"
    echo "Expectation: Env must match with tcsh after the command"
    if [[ ! -z "$WITH_ENV" ]]; then
        echo "With environment variables: $WITH_ENV"
    fi
    echo "---"
    DIFF=$(diff --color=always <(echo "$@"$'\n'"env" | env -i $SAMPLE_ENV tcsh 2>&1 | grep -v "^SHLVL=") <(echo "$@"$'\n'"env" | env -i $SAMPLE_ENV $WITH_ENV ./mysh 2>&1 | grep -v "^SHLVL="))
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

cleanup()
{
    pkill -P $$
}

total() {
    echo ""
    echo ""
    echo "Tests passed: $(echo -n $PASSED | wc -m). Tests failed: $(echo -n $FAILED | wc -m)."
}

trap EXIT cleanup

tests
total
cleanup