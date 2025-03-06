#!/bin/bsah
 
# info system
#######constante
Title="kali info system"
jj="$(date +"%x %r%z")"
mj="Mis àjour $jj sur $USER"

##########Fonction

info_user()
{

        echo "Fonction  information utilisateur"

}
###df
info_disk()
{

	echo "Fonction information sur le disk"

}
#####printenv
info_chemin()
{

	echo "Fonction  information sur les variables d'environnement"

}
##### uptimi
show_time()
{

	echo "Fonction pour voir le temps"
}




#######main
cat << _EOF_ 
<html>
<head>
<title> $Title  </titre>
</head>
<body> 

<h1> $Title </h1>

<p> $mj </p>

 $(info_user)
$(info_disk) 
$(info_chemin) 
$(show_time)


 </body>
</html>
_EOF_
