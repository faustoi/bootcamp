#!/usr/bin/env bash

## rapidly curl a random tweet (selected from a list of tweets)

read -r -d '' TXT <<- EOM
871833247231201286
871831454929620992
871831035385966593
871832578361315332
871832754228473858
871832771882299392
871831408813199360
871831056734965760
871829366707245057
871832266770698241
871832976102916098
871829422298599424
871832519100035081
871830352402284549
871832399298138112
871831987098669058
871831458008223745
871832024247652352
871833245863817217
871833474050662400
871831511460458497
871832728915804161
871833900435243009
871832306239111168
871832123409391618
871832189842968578
871833162372063232
871831699134570498
871830118464761856
871833356018876418
871829716533202944
871829822061912065
871831963241517056
871829794870009856
871831683879796739
871833798291443712
871830352016396289
871832351193432064
871830406806609920
871834053573459968
871832242007547910
871831827610292224
871829415189237760
871829469861949440
871829648996528128
871829471040589826
871831314990735360
871834068949782528
871830023300419588
871834099974942720
871831118860996608
871834037974728704
871830213721812992
871833284250148869
871830642991824896
871832240631668736
871831879741296642
871833751126409217
871830108612378624
871830445650046976
871830242603741184
871830669781086210
871832354981105664
871832444932153350
871832790106611712
871833032998625281
871831789425262592
871832889654210560
871832206725062658
871832358923653120
871833133502656513
871830119207370753
871833503322734597
871830451941515264
871833784211189762
871831415666749441
871833303984218113
871829771704909825
871830639007465475
871830747237277700
871833930986639361
871834048447905792
871831765849186305
871829548245164032
871831388374355969
871832543724793858
871833983788756992
871832402464821248
871832680496844801
871829829502599168
871831813274050560
871829713290919936
871829480691585024
871832357392830465
871833237357813761
871832557779865601
871829364572401666
871832054341697536
871833107317522432
871829679388413953
000000000000000000
000000000000000000
000000000000000000
000000000000000000
000000000000000000
000000000000000000
000000000000000000
000000000000000000
000000000000000000
EOM

# convert to array
ARR=($TXT)

RANDOM=$$$(date +%s)

while true
do
    tweet=${ARR[$RANDOM % ${#ARR[@]} ]}
    echo $tweet
    curl -s http://localhost:8080/getTweet?tweetId=${tweet} > /dev/null
    #sleep 1
done