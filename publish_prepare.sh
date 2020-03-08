rm -rf publish && mkdir publish

# ChatAdditions_Core
mkdir -p publish/ChatAdditions_Core/amxmodx/configs
mkdir -p publish/ChatAdditions_Core/amxmodx/scripting/include

cp amxmodx/configs/plugins-ChatAdditions.ini    publish/ChatAdditions_Core/amxmodx/configs/
cp amxmodx/scripting/include/ChatAdditions.inc  publish/ChatAdditions_Core/amxmodx/scripting/include/
cp amxmodx/scripting/ChatAdditions_Core.sma     publish/ChatAdditions_Core/amxmodx/scripting/

cd publish && tar -cvzf ChatAdditions_Core.tar.gz ChatAdditions_Core/* && cd ..

rm -rf publish/ChatAdditions_Core

# ChatAdditions: Gag
mkdir -p publish/CA_Gag/amxmodx/configs/ChatAdditions
mkdir -p publish/CA_Gag/amxmodx/data/lang
mkdir -p publish/CA_Gag/amxmodx/scripting/include/ChatAdditions_inc/

cp amxmodx/scripting/CA_Gag.sma                     publish/CA_Gag/amxmodx/scripting/
cp amxmodx/scripting/include/CA_GAG_API.inc         publish/CA_Gag/amxmodx/scripting/include/
cp amxmodx/scripting/include/ChatAdditions_inc/*    publish/CA_Gag/amxmodx/scripting/include/ChatAdditions_inc/
cp amxmodx/data/lang/CA_Gag.txt                     publish/CA_Gag/amxmodx/data/lang/
cp amxmodx/configs/ChatAdditions/*                  publish/CA_Gag/amxmodx/configs/ChatAdditions/

cd publish && tar -cvzf CA_Gag.tar.gz CA_Gag/* && cd ..

rm -rf publish/CA_Gag


# ChatAdditions: Mute
mkdir -p publish/CA_Mute/amxmodx/data/lang
mkdir -p publish/CA_Mute/amxmodx/scripting/

cp amxmodx/scripting/CA_Mute.sma    publish/CA_Mute/amxmodx/scripting/
cp amxmodx/data/lang/CA_Mute.txt    publish/CA_Mute/amxmodx/data/lang/

cd publish && tar -cvzf CA_Mute.tar.gz CA_Mute/* && cd ..

rm -rf publish/CA_Mute