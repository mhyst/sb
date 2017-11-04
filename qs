#!/bin/bash
#################################################################################################
# V A R I A B L E S
#################################################################################################

SQLITE="sqlite3 /home/mhyst/bin/scripts/seriesblanco/sbdb"
#Nombre del script
CODENAME="qs"
#Current version
VERSION="0.0.1"

#################################################################################################
# Funciones reutilizables
#################################################################################################

function userChoice() {

	local limite=$1
	local cadena="$2"
	local reply
	let reply=0

	echo > /dev/tty
	echo "$cadena" > /dev/tty
	read reply < /dev/tty
	echo > /dev/tty

	#We see if the user entered a number such as we need
	while [[ "$reply" -lt 0 ]] || [[ "$reply" -gt  $limite ]]; do

		#We give advice to the user and exit
		echo "Tiene que introducir un número de entre los indicados:" > /dev/tty
		read reply < /dev/tty
		#echo "Reply es: $reply" > /dev/tty

	done

	echo $reply
}

trim() {
	local FOO="$1"
	FOO_NO_EXTERNAL_SPACE="$(echo -e "${FOO}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	echo "$FOO_NO_EXTERNAL_SPACE"
}

##################################################################################################
# Funciones base de datos
#-------------------------------------------------------------------------------------------------
# Todas ellas contendrán query en su nombre
##################################################################################################

function querySeries() {
	local search="$1 $2 $3 $4 $5 $6 $7 $8 $9"

	search=$(trim $search)

	local res=`$SQLITE "select * from series where titulo like '%$search%'"`
	echo "$res"
}

function queryTemporadas() {
	local idserie="$1"

	if $vervistos; then
		local res=`$SQLITE "select distinct(temporada) from episodios where idserie = $idserie"`
	else
		local res=`$SQLITE "select distinct(temporada) from episodios where idserie = $idserie and visto = 0"`
	fi

	echo "$res"
}

function queryEpisodios() {
	local idserie="$1"
	local temporada="$2"

	if $vervistos || (( $temporada > 0)); then
		local res=`$SQLITE "select * from episodios where idserie = $idserie and temporada = $temporada"`
	else
		local res=`$SQLITE "select * from episodios where idserie = $idserie and temporada = $temporada and visto = 0"`
	fi
	echo "$res"
}

function queryEpisodio() {
	local idserie="$1"
	local temporada="$2"
	local episodio="$3"

	#echo "SQL=select * from episodios where idserie = $idserie and temporada = $temporada and episodio = $episodio" > /dev/tty
	local res=`$SQLITE "select * from episodios where idserie = $idserie and temporada = $temporada and episodio = $episodio"`
	echo "$res"
}

function setVisto() {
	local idepisodio="$1"

	local res=`$SQLITE "update episodios set visto=visto+1 where id = $idepisodio"`
	echo "$res"	
}

function queryEnlaces() {
	local idserie="$1"
	local idepisodio="$2"

	local res=`$SQLITE "select * from enlaces where idserie = $idserie and idepisodio = $idepisodio"`
	echo "$res"
}

function queryEnlacesFiltro() {
	local idserie="$1"
	local idepisodio="$2"
	local servicio="$3"

	#echo "select * from enlaces where idserie = $idserie and idepisodio = $idepisodio and url like '%$servicio%'" > /dev/tty
	local res=`$SQLITE "select * from enlaces where idserie = $idserie and idepisodio = $idepisodio and url like '%$servicio%'"`
	echo "$res"
}

function parseSerie () {
	local chain="$1"

	IFS='|' read -r -a array <<< "$chain"
	local serie="${array[1]}"

	echo "$serie"
}

function parseIDSerie () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local serie="${array[0]}"
	IFS=$oIFS

	echo "$serie"
}

function parseIDEpisodio () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[0]}"
	IFS=$oIFS

	echo "$episodio"
}

function parseEpisodio () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[3]}"
	IFS=$oIFS

	echo "$episodio"
}

function parseServicio () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[4]::-4}"
	IFS=$oIFS

	echo "$episodio"
}

function parseEnlace () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[3]}"
	IFS=$oIFS

	echo "$episodio"
}

function help {
	echo "$CODENAME $VERSION - Copyleft (GPL v3) Julio Serrano 2017"
	echo "Consulta la base de datos creara con sbpopulate"
	echo
	echo "Modo de empleo: $CODENAME [opción] <cadena de búsqueda>"
	echo
	echo " Ejemplos:"
	echo "	$CODENAME discovery"
	echo
	echo "	$CODENAME -t 9 se ha escrito un crimen"
	echo
	echo "	$CODENAME -t 1 -c 7 el mentalista"
	echo
	echo "	$CODENAME -t 2 -c 2 -s streamcloud the orville"
	echo
	echo "	$CODENAME -v -s streamcloud poldark"
	echo
	echo "Opciones"
	echo " -t"
	echo "      Filtrar por temporada."
	echo
	echo " -c"
	echo "      Filtrar por capítulo."
	echo
	echo " -s"
	echo "      Filtrar por servicio."
	echo
	echo " -v"
	echo "      Mostrar temporadas y episodios ya vistos."
	echo
	echo " -l"
	echo "      Limitar listado de episodios a 10."
	echo
}

#################################################################################################
# P R O G R A M A      P R I N C I P A L
#################################################################################################

TEMP=`getopt -o ht:c:s:lv --long "help,temporada:,capitulo:,servicio:,limit" -- "$@"`



if [ $? != 0 ]; then help; exit 1; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"


# Debug
#echo "$TEMP"

# VER_NO_VISTOS=false
# VER_VISTOS=false
# forth_number=0
# forth_all=false
# reset=false
# reset_by=false
# back=0
# reset_data=()
temporada=0
capitulo=0
servicio=""
limit=false
vervistos=false

while true; do
  case "$1" in
  	-h | --help ) help; exit ;;
	-t | --temporada ) temporada=$2; shift ;;
	-c | --capitulo) capitulo=$2; shift ;;
	-s | --servicio) servicio=$2; shift ;;
	-l | --limit) limit=true ;;
	-v) vervistos=true ;;
	# -b | --back ) let back++ ;;
	# -f | --forth ) let forth_number++ ;;
	# --forth-by ) forth_number=$2; shift ;;
	# -a | --forth-all ) forth_all=true ;;
	# -n ) VER_NO_VISTOS=true ;;
    # -v ) VER_VISTOS=true ;;
	# -r | --reset ) reset=true ;;
	# -m | --mreset ) reset_data+=("$2"); shift ;;
	# --reset-by ) reset_by=true; bydata=$2; shift ;;
    * ) break ;;
  esac
  shift
done

if [[ $1 = "--" ]]; then
	shift
fi

# echo "Parámetros: $temporada $capitulo $servicio"
# echo "Argumentos: $1 $2 $3 $4 $5 $6 $7 $8 $9"
# PARM=""
# for arg in $@; do
# 	if [[ $1 != "--" ]]; then
# 		PARM="$PARM$1 "
# 	fi
# 	shift
# done

#PARM=$(trim $PARM)

echo "$CODENAME $VERSION - Copyleft (GPL v3) Julio Serrano 2017"
echo "Consulta la base de datos creara con sbpopulate"
echo


SERIES=$(querySeries "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9")


echo "Series que coinciden con su cadena de búsqueda: "
echo
#Dividir series por nueva línea
readarray -t aseries <<<"$SERIES"

#Recorrer el array resultante "y"
let i=0
for t in "${aseries[@]}"; do
	nombreserie=$(parseSerie "$t")
	echo "	$i:	$nombreserie"
	((i++))
done

LIMITE=$(( ${#aseries[*]} - 1 ))
CHOSENID=$(userChoice $LIMITE "Seleccione la serie:")

#echo "El elegido es: ${aseries[$CHOSENID]}"
echo

#Extraer el nombre de la serie para futuros usos
SERIE=$(parseIDSerie "${aseries[$CHOSENID]}")

nombreserie=$(parseSerie "${aseries[$CHOSENID]}")
echo "Ha escogido $nombreserie"

if [[ $temporada == 0 ]]; then
	TEMPORADAS=$(queryTemporadas "$SERIE")


	echo "Temporadas disponibles:"
	echo
	readarray -t atemporadas <<<"$TEMPORADAS"

	let i=0
	for t in "${atemporadas[@]}"; do
		echo "	$i:	Temporada $t"
		((i++))
	done

	LIMITE=$(( ${#atemporadas[*]} - 1 ))
	CHOSENID=$(userChoice $LIMITE "Seleccione la temporada: ")

	TEMPORADA="${atemporadas[$CHOSENID]}"
else
	TEMPORADA="$temporada"
fi

echo "Ha elegido la temporada $TEMPORADA"

echo

if [[ $capitulo == 0 ]]; then

	EPISODIOS=$(queryEpisodios "$SERIE" "$TEMPORADA")

	echo "Episodios de la temporada $TEMPORADA:"
	echo

	readarray -t aepisodios <<<"$EPISODIOS"

	let i=0
	for t in "${aepisodios[@]}"; do
		echo "	$i:	Episodio $(parseEpisodio $t)"

		if $limit; then
			if (( i == 10 )); then
				break
			fi
		fi
		((i++))
	done

	LIMITE=$(( ${#aepisodios[*]} - 1 ))
	CHOSENID=$(userChoice $LIMITE "Seleccione el episodio que quiere ver: ")

	EPISODIO="${aepisodios[$CHOSENID]}"
	IDEPISODIO=$(parseIDEpisodio "$EPISODIO")
else
	EPISODIO=$(queryEpisodio "$SERIE" "$temporada" "$capitulo")
	echo "$EPISODIO"
	IDEPISODIO=$(parseIDEpisodio "$EPISODIO")

fi

echo "Ha escogido el episodio $EPISODIO --> código $IDEPISODIO"

echo


if [[ $servicio == 0 ]]; then
	ENLACES=$(queryEnlaces "$SERIE" "$IDEPISODIO")
else
	ENLACES=$(queryEnlacesFiltro "$SERIE" "$IDEPISODIO" "$servicio")
fi

echo "Enlaces del episodio $EPISODIO de la temporada $TEMPORADA: "
echo

readarray -t aenlaces <<<"$ENLACES"

let i=0
for t in "${aenlaces[@]}"; do
	echo "	$i:	$(parseServicio $t)"
	((i++))
done

LIMITE=$(( ${#aenlaces[*]} - 1 ))
CHOSENID=$(userChoice $LIMITE "Seleccione el enlace: ")

ENLACE=$(parseEnlace "${aenlaces[$CHOSENID]}")

echo "Este es el enlace que ha seleccionado:"
echo
echo "$ENLACE"
echo
echo "Que disfrute del episodio!"

VISTO=$(setVisto "$IDEPISODIO")
echo "$VISTO"