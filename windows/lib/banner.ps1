$beetle = @"

          ##########        ##########
          ##      ##        ##      ##
          ####    ####    ####    ####      
                    ########                
                    ########                
            ########################        
      ##    ########################       
      ####################################    BBBBBBBB  EEEEEEEE  EEEEEEEE  TTTTTTTT  LL        EEEEEEEE
            ########################    ##    BB    BB  EE        EE           TT     LL        EE
      ##    ########################          BBBBBBBB  EEEEEE    EEEEEE       TT     LL        EEEEEE
      ####################################    BB    BB  EE        EE           TT     LL        EE
            ########################    ##    BBBBBBBB  EEEEEEEE  EEEEEEEE     TT     LLLLLLL   EEEEEEEE
      ##    ########################
      ####################################
            ########################    ##
            ########################
                ################
                  ##        ##       
                  ##        ##  
         +----------------------------+
         |      OS HARDENING TOOL     |
         +----------------------------+
"@


foreach ($line in $beetle -split "`n") {
    foreach ($char in $line.ToCharArray()) {
        if ($char -eq '#') {
            Write-Host $char -NoNewline -ForegroundColor DarkGreen
        }
        else {
            Write-Host $char -NoNewline -ForegroundColor Blue
        }
    }
    Write-Host ""
}
