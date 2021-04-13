#!/usr/bin/env bash

# See LICENSE file for copyright and license details
# A snake-like game written in Bash. Version 0.9

ts=$(stty -g)       # Save terminal settings
x=40                # Map length
y=16                # Map heigth
s=$(($x*$y))        # Map area (size)
last_direction=left # Snake start direction
snake_skin=@        # The snake is alive @
snake_grow=$((0))   # How many units the snake will grow
declare -a map      # Byte array printed on screen. Collision detection.
declare -a snake    # List of (x,y) tuples
food=               # String of "$,x,y" tuples separated by white space

function init_map () {
	clear_map
}

function clear_map () {
	for ((i=0;i<$s;i++)); do
		map[$i]=" " 
	done
}

# Place what (character) where (x,y)
function place_on_map () {
	map[$(($3*$x+$2))]="$1"
}

function retrieve_from_map () {
	echo "${map[$(($2*$x+$1))]}"
}

function set_border () {
	for ((i=0;i<$x;i++)); do
		map[$i]="#"
		map[((($y-1)*$x+$i))]="#"
	done
	for ((i=0;i<$y;i++)); do
		map[$(($i*$x))]="#"
		map[$(($i*$x+($x-1)))]="#"
	done
}

function init_snake () {
	snake=($(($x/2)) $(($y/2)))
	snake+=($((${snake[0]}+1)) ${snake[1]})
	snake+=($((${snake[0]}+2)) ${snake[1]})
}

function set_snake () {
	for ((i=0;i<${#snake[@]};i+=2)); do
		place_on_map $snake_skin ${snake[$i]} ${snake[$(($i+1))]}
	done
}

function set_food () {
	for i in $food; do
		if [[ $i =~ .,[0-9]+,[0-9]+ ]]; then
			match="${BASH_REMATCH[0]}"
			match=${match//,/' '}
			place_on_map $match
		fi
	done
}

function draw_map () {
	clear_map
	set_border
	set_snake
	set_food
	t=
	for ((i=0;i<$y;i++)); do
		for ((j=0;j<$x;j++)); do
			t="$t${map[$(($i*$x+$j))]}"
		done
		t="$t"\\n
	done
	echo -en "\e[${y}A$t"
}

# Finds a random empty location to drop the food. Avoid collision with snake,
# borders and other food.
function add_food () {
	declare -a empty_x
	declare -a empty_y

	for ((i=0;i<$s;i++)); do
		if [[ "${map[$i]}" == " " ]]; then
			empty_x+=($(($i%$x)))
			empty_y+=($(($i/$x)))
		fi
	done
	idx=$(($RANDOM%${#empty_x[@]}))
	f='$',${empty_x[$idx]},${empty_y[$idx]}
	if [[ -z "$food" ]]; then
		food="$f"
	else
		food="$food $f"
	fi
	unset empty_x
	unset empty_y
}

# Remove, delete possible double spaces, trim
function delete_food () {
	food=${food/'$',$1,$2}
	food=${food//'  '/' '}
	food=${food##*( )}
	food=${food%%*( )}
}

function move_snake () {
	if (($snake_grow == 0)); then
		unset snake[-1]
		unset snake[-1]
	else
		((snake_grow--))
	fi
	snake=($1 $2 ${snake[@]})
}

function move () {
	direction=$last_direction
	case "$last_direction" in
	up|down)
		if [[ $1 == right || $1 == left ]]; then
			direction=$1
		fi
		;;
	right|left)
		if [[ $1 == up || $1 == down ]]; then
			direction=$1
		fi
		;;
	esac
	nextx=${snake[0]}
	nexty=${snake[1]}
	case "$direction" in
	up) ((nexty--));;
	down) ((nexty++));;
	right) ((nextx++));;
	left) ((nextx--));;
	esac
	val=$(retrieve_from_map $nextx $nexty)
	case "$val" in
	'@'|'#') snake_skin=X;;
	'$')
		snake_grow=$(($snake_grow+3))
		move_snake $nextx $nexty
		delete_food $nextx $nexty
		add_food
		;;
	*) move_snake $nextx $nexty;;
	esac
	draw_map
	last_direction=$direction
}

function cleanup () {
	unset map
	unset snake
	unset food
	stty "$ts"
	echo -en "\e[?25h" # Cursor on
}

function signal_handler () {
	cleanup
	kill -s SIGKILL $$
}

trap signal_handler SIGINT

for ((i=0;i<$y;i++)); do echo; done # TTY auto-scroll needs this?
stty -echo -icanon  # Do not echo keys, enable non-blocking read
echo -en "\e[?25l"  # Cursor off
init_map
init_snake
draw_map
add_food
add_food
add_food

# Main loop. Read single characters from standard input until the next key is
# found. Arrow keys are multi-byte characters and need special treatment. If
# no known key is found, the snake keeps on moving into the last direction.
while [[ "$snake_skin" == '@' ]]; do
	key=
	m=
	c=
	if read -s -t 0; then
		read -s -N 1 c
		case "$c" in 
		$'\e')
			key="$c"
			read -s -N 1 c
			case "$c" in
			'[')
				key="$key$c"
				read -s -N 1 c
				case "$c" in
				A|B|C|D)
					key="$key$c"
					;;
				*)
					key=""
					;;
				esac
				;;
			*)
				key=""
				;;
			esac
			;;
		q|p)
			key="$c"
			;;
		*)
			:;;
		esac
	fi

	case "$key" in
	q) echo Quit.; break;;
	$'\e[A') m=up;;
	$'\e[B') m=down;;
	$'\e[C') m=right;;
	$'\e[D') m=left;;
	*) :;; #ignore
	esac

	move $m
	sleep 0.25
done

cleanup
