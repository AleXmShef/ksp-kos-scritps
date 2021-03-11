//if not exists("1:/Soyuz TMA.ks") {
    copypath("0:/libs/Crafts/Fregat M.ks", "1:/").
//}
//if not exists("1:/LibManager.ks") {
    copypath("0:/libs/LibManager.ks", "1:/").
//}
runoncepath("1:/LibManager.ks").
runoncepath("1:/Fregat M.ks").
