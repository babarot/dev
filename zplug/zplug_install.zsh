#!/bin/zsh

typeset -A repo_pids states hook_build hook_finished hook_pids
typeset -F SECONDS=0
typeset -a spinners points repos
typeset -i p=0 c=0
typeset    repo

typeset ZPLUG_HOME="."
typeset ZPLUG_MANAGE="$ZPLUG_HOME/.zplug"
typeset hook_success="$ZPLUG_MANAGE/.hook_success"
typeset hook_failure="$ZPLUG_MANAGE/.hook_failure"
typeset hook_rollback="$ZPLUG_MANAGE/.hook_rollback"

mkdir -p "$ZPLUG_MANAGE"

spinners=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
points=(. . .. .. ... ... .... ....)
points=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
points=('⠋' '⠙' '⠚' '⠞' '⠖' '⠦' '⠴' '⠲' '⠳' '⠓')
points=('⠋' '⠙' '⠚' '⠒' '⠂' '⠂' '⠒' '⠲' '⠴' '⠦' '⠖' '⠒' '⠐' '⠐' '⠒' '⠓' '⠋')
points=('⠁' '⠁' '⠉' '⠙' '⠚' '⠒' '⠂' '⠂' '⠒' '⠲' '⠴' '⠤' '⠄' '⠄' '⠤' '⠠' '⠠' '⠤' '⠦' '⠖' '⠒' '⠐' '⠐' '⠒' '⠓' '⠋' '⠉' '⠈' '⠈')

any() {
    local job
    for job in "$argv[@]"
    do
        if [[ $jobstates =~ $job ]]; then
            return 0
        fi
    done
    return 1
}

eraceCurrentLine() {
    printf "\033[2K\r"
}

repos=(
b4b4r07/enhancd
b4b4r07/gomi
b4b4r07/dotfiles
zplug/zplug
zsh-users/antigen
fujiwara/nssh
)

for repo in "$repos[@]"
do
    sleep $(( $RANDOM % 5 + 1 )).$(( $RANDOM % 9 + 1 )) &
    repo_pids[$repo]=$!
    hook_build[$repo]=""
    hook_finished[$repo]=false
    states[$repo]="unfinished"
done

hook_build[fujiwara/nssh]="sleep 3; false"
hook_build[b4b4r07/gomi]="sleep 2"

printf "[zplug] Start to install $#repos plugins in parallel\n\n"
repeat $(($#repos + 2))
do
    printf "\n"
done

while any "$repo_pids[@]" "$hook_pids[@]"; do
    sleep 0.1
    printf "\033[%sA" $(($#repos + 2))

    # Count up within spinners index
    if (( ( c+=1 ) > $#spinners )); then
        c=1
    fi
    # Count up within points index
    if (( ( p+=1 ) > $#points )); then
        p=1
    fi

    for repo in "${(k)repo_pids[@]}"
    do
        if [[ $jobstates =~ $repo_pids[$repo] ]]; then
            printf " $fg[white]${spinners[$c]}$reset_color  Installing...  $repo\n"
        else
            # If repo has build-hook tag
            if [[ -n $hook_build[$repo] ]]; then
                if ! $hook_finished[$repo]; then
                    hook_finished[$repo]=true
                    {
                        eval ${=hook_build[$repo]}
                        if (( $status > 0 )); then
                            # failure
                            printf "$repo\n" >>|"$hook_failure"
                            printf "__zplug::job::hook::build ${(qqq)repo}\n" >>|"$hook_rollback"
                        else
                            # success
                            printf "$repo\n" >>|"$hook_success"
                        fi
                    } & hook_pids[$repo]=$!
                fi

                if [[ $jobstates =~ $hook_pids[$repo] ]]; then
                    # running build-hook
                    eraceCurrentLine
                    printf " $fg_bold[white]${spinners[$c]}$reset_color  $fg[green]Installed!$reset_color     $repo --> hook-build: ${points[$p]}\n"
                else
                    # finished build-hook
                    eraceCurrentLine
                    if [[ -f $hook_failure ]] && grep -x "$repo" "$hook_failure" &>/dev/null; then
                        printf " $fg_bold[white]\U2714$reset_color  $fg[green]Installed!$reset_color     $repo --> hook-build: $fg[red]failure$reset_color\n"
                    else
                        printf " $fg_bold[white]\U2714$reset_color  $fg[green]Installed!$reset_color     $repo --> hook-build: $fg[green]success$reset_color\n"
                    fi
                fi
            else
                printf " $fg_bold[white]\U2714$reset_color  $fg[green]Installed!$reset_color     $repo\n"
            fi
            states[$repo]="finished"
        fi
    done

    printf "\n"
    if any "$repo_pids[@]" "$hook_pids[@]"; then
        printf "[zplug] Finished: ${(k)#states[(R)finished]}/$#states plugin(s)\n"
    else
        eraceCurrentLine
        printf "[zplug] Elapsed time: %.4f sec.\n" $SECONDS
    fi
done

rm "$hook_success" "$hook_failure"