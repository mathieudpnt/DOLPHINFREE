########################################################################
#    STATISTICS
#    Author : Loic LEHNHOFF
#    Adapted from Yannick OUTREMAN 
#    Agrocampus Ouest - 2020
#######################################################################
library(pscl)
library(MASS)
library(lmtest)
library(multcomp)
library(emmeans)
library(dplyr)        # "%>%" function
library(forcats)      # "fct_relevel" function
library(stringr)      # "gsub" function 
library(rcompanion)   # "fullPTable" function
library(multcompView) # "multcompLetters" function
library(ggplot2)
#library(tidyquant)    # geom_ma() if rolling average needed


################# DATASET IMPORTS #####################################
folder <- './../'
bbp.dta <-read.table(file=paste0(folder, 
                                'BBPs/Results/16-06-22_14h00_number_of_BBP.csv'),
                     sep = ',', header=TRUE)
bbp.dta <- bbp.dta[order(bbp.dta$audio_names),]

# suppress "T" acoustic data (other groups not tested on our variables)
bbp.dta <- bbp.dta[bbp.dta$acoustic!="T",]
# shuffle dataframe
bbp.dta <- bbp.dta[sample(1:nrow(bbp.dta)), ]
bbp.dta$acoustic <- factor(bbp.dta$acoustic)

#################### DATA INSPECTION  #################################
# Data description
names(bbp.dta)
# self explenatory except acoustic : correspond to the activation sequence.

# Look for obvious correlations
plot(bbp.dta) # nothing that we can see

# Look for zero-inflation
100*sum(bbp.dta$number_of_BBP == 0)/nrow(bbp.dta)
100*sum(bbp.dta$Buzz == 0)/nrow(bbp.dta)
100*sum(bbp.dta$Burst.pulse == 0)/nrow(bbp.dta)
# 53.7%, 60.1% & 73.6% of data are zeroes

# QUESTION: This study is aimed at understanding if dolphin's acoustic activity
# is influenced bytheir behavior, the emission of a pinger or a fishing net.

# Dependent variables (Y): number_of_BBP, Buzz & Burst.pulse 
# Explanatory variables (X): acoustic, fishing_net, behavior, beacon, net, number.

# What are the H0/ H1 hypotheses ?
# H0 : No influence of any of the explanatory variables on a dependant one.
# H1 : Influence of an explanatory variable on a dependent one.

##################### DATA EXPLORATION ################################
# Y Outlier detection
par(mfrow=c(2,3))
boxplot(bbp.dta$number_of_BBP, col='red', 
        ylab='number_of_BBP')
boxplot(bbp.dta$Buzz, col='red', 
        ylab='Buzz')
boxplot(bbp.dta$Burst.pulse, col='red', 
        ylab='Burst.pulse')

dotchart(bbp.dta$number_of_BBP, pch=16, 
         xlab='number_of_BBP', col='red')
dotchart(bbp.dta$Buzz, pch=16, 
         xlab='Buzz', col='red')
dotchart(bbp.dta$Burst.pulse, pch=16, 
         xlab='Burst.pulse', col='red')

# Y distribution
par(mfrow=c(2,3))
hist(bbp.dta$number_of_BBP, col='red', breaks=8,
     xlab='number_of_BBP', ylab='number')
hist(bbp.dta$Buzz, col='red', breaks=8,
     xlab='Buzz', ylab='number')
hist(bbp.dta$Burst.pulse, col='red', breaks=8,
     xlab='Burst.pulse', ylab='number')

qqnorm(bbp.dta$number_of_BBP, col='red', pch=16)
qqline(bbp.dta$number_of_BBP)
qqnorm(bbp.dta$Buzz, col='red', pch=16)
qqline(bbp.dta$Buzz)
qqnorm(bbp.dta$Burst.pulse, col='red', pch=16)
qqline(bbp.dta$Burst.pulse)

shapiro.test(bbp.dta$number_of_BBP)
shapiro.test(bbp.dta$Buzz)
shapiro.test(bbp.dta$Burst.pulse)
# p-values are significant => they do not follow normal distributions
# we will need transformations or the use of glm models

# X Number of individuals per level
summary(factor(bbp.dta$acoustic))
summary(factor(bbp.dta$fishing_net))
summary(factor(bbp.dta$behavior))
summary(factor(bbp.dta$beacon))
summary(factor(bbp.dta$net))
table(factor(bbp.dta$acoustic),factor(bbp.dta$fishing_net))
table(factor(bbp.dta$acoustic),factor(bbp.dta$behavior))
table(factor(bbp.dta$behavior),factor(bbp.dta$acoustic))
ftable(factor(bbp.dta$fishing_net), factor(bbp.dta$behavior), factor(bbp.dta$acoustic))
# => unbalanced, no big deal but will need more work (no orthogonality):
# Effects can depend on the order of the variables 

# => Beacon and net have modalities with <10 individuals => analysis impossible
# => They will be treated apart from the rest as they are likely to be biased


##################### STATISTICAL MODELLING ###########################
### Model tested
# LM: Linear model (residual hypothesis: normality, homoscedasticity, independant)
# GLM: Generalized linear model (residual hypothesis: homoscedasticity, independant)
# NB : Negative Binomial model (usually, when overdispersion with GLM)
# ZINB: Zero inflated negative binomial model (residual hypothesis: homoscedasticity, independant
# using number as an offset (more dolphins => more signals)

# beacon and net explanatory variables could not be tested in models 
# as they contain information already present in "fishing_net" which is more 
# interesting to keep for our study. They will be treated after 
# (using kruskall-Wallis non-parametric test)
# fishing_net, behavior and acoustic where tested with their interactions.
# If a variable is it in a model, it is because it had no significant effect.

### Model for BBP
# No normality of residuals for LM
# overdispersion with GLM quasipoisson
#try with glm NB:
mod.bbp <- glm.nb(number_of_BBP ~ acoustic + fishing_net + behavior 
                  + offset(log(number)),
                  data=bbp.dta)
car::Anova(mod.bbp, type=3)
dwtest(mod.bbp) # H0 -> independent if p>0.05 (autocorrelation if p<0.05)
bptest(mod.bbp) # H0 -> homoscedasticity if p<0.05
# Normality not needed in GLM, hypotheses verified !
mod.bbp$deviance/mod.bbp$df.residual 
# slight underdispersion

### Model for Buzzes
# No normality of residuals for LM
# overdispersion with GLM quasipoisson
# underdispersion with glm NB
# Try with ZINB:
mod.buzz <- glm.nb(Buzz ~ behavior + fishing_net + acoustic
                   + offset(log(number)),
                   data=bbp.dta)
car::Anova(mod.buzz, type=3)
dwtest(mod.buzz) # H0 -> independent if p>0.05 (autocorrelation if p<0.05)
bptest(mod.buzz) # H0 -> homoscedasticity if p<0.05
mod.buzz$df.null/mod.buzz$df.residual 
# No overdispersion

### Model for Burst-pulses
# No normality of residuals for LM
# overdispersion with quasipoisson
# underdispersion with NB
# ZINB is working :
mod.burst.pulse <- zeroinfl(Burst.pulse ~ fishing_net + acoustic + behavior
                             + offset(log(number)), dist="negbin",
                             data=bbp.dta)
car::Anova(mod.burst.pulse, type=3)
dwtest(mod.burst.pulse) # H0 -> independent if p>0.05 (autocorrelation if p<0.05)
bptest(mod.burst.pulse) # H0 -> homoscedasticity if p<0.05
mod.burst.pulse$df.null/mod.burst.pulse$df.residual  # -> Overdispersion of != 1
# no overdispersion
 

##################### Boxplots and comparisons ##################### 
### Functions to compute stats
computeLetters <- function(temp, category) {
  test <- multcomp::cld(object = temp$emmeans,
                        Letters = letters)
  myletters_df <- data.frame(category=test[,category],
                             letter=trimws(test$.group))
  colnames(myletters_df)[1] <- category
  return(myletters_df)
}

computeStats <- function(data, category, values, two=NULL, three=NULL) {
  my_sum <- data %>%
    group_by({{category}}, {{two}}, {{three}}) %>% 
    summarise( 
      n=n(),
      mean=mean({{values}}),
      sd=sd({{values}})
    ) %>%
    mutate( se=sd/sqrt(n))  %>%
    mutate( ic=se * qt((1-0.05)/2 + .5, n-1))
  return(my_sum)
}

barPlot <- function(dta, signif, category, old_names, new_names, fill=NULL, size=5,
                    height, xname="", colours="black", legend_title="", legend_labs="",ytitle=""){
  if (!is.null(signif)){colnames(signif)[1] <- "use"}
  
  dta %>%
    mutate(use=fct_relevel({{category}}, old_names)) %>%
    ggplot(aes(x=use, y=mean, group={{fill}}, fill={{fill}},color={{fill}}, na.rm = TRUE)) +
    {if(length(colours)==1)geom_point(color=colours, position=position_dodge(.5))}+
    {if(length(colours)>=2)geom_point(position=position_dodge(.5), show.legend = FALSE)}+
    {if(length(colours)>=2)scale_color_manual(values=colours, name=legend_title, labels=legend_labs)}+
    scale_x_discrete(breaks=old_names,
                     labels=new_names)+
    ylab(ytitle)+
    xlab(xname)+
    theme_classic()+ theme(text=element_text(size=12))+
    {if(!is.null(signif))geom_text(data=signif, aes(label=letter, y=height), size=size,
                                   colour="black", position=position_dodge(.5))}+
    geom_errorbar(aes(x=use, ymin=mean-ic, ymax=mean+ic), position=position_dodge(.5), width=.1, show.legend = FALSE)
  
}

####Introducing variables averaged per dolphins ####
# since we introduced an offset, variables can be divided by the number of dolphins
bbp.dta$BBPs_per_dolphin <- bbp.dta$number_of_BBP/bbp.dta$number
bbp.dta$Buzz_per_dolphin <- bbp.dta$Buzz/bbp.dta$number
bbp.dta$Burst.pulse_per_dolphin <- bbp.dta$Burst.pulse/bbp.dta$number

#### Fishing nets plots  ####
par(mfrow=c(3, 1))
# BBPs
table <- cld(emmeans(mod.bbp, pairwise~fishing_net, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(fishing_net=table$fishing_net,
                           letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, fishing_net, BBPs_per_dolphin),
        myletters_df, fishing_net,         
        old_names = c("SSF","F"), new_names = c("Absent", "Present"),
        xname="Presence/Asence of fishing net", height=.6, 
        ytitle="Mean number of BBP per dolphin per min")
# Buzz
table <- cld(emmeans(mod.buzz, pairwise~fishing_net, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(fishing_net=table$fishing_net,
                           letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, fishing_net, Buzz_per_dolphin),
        myletters_df, fishing_net,
        ytitle="Mean number of Buzzes per dolphin per min",
        old_names = c("SSF","F"), new_names = c("Absent", "Present"),
        xname="Presence/Asence of fishing net", height=.45)
# Burst-pulse
table <- cld(emmeans(mod.burst.pulse, pairwise~fishing_net, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(fishing_net=table$fishing_net,
                           letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, fishing_net, Burst.pulse_per_dolphin),
        myletters_df, fishing_net,
        ytitle="Mean number of Burst-pulses per dolphin per min",
        old_names = c("SSF","F"), new_names = c("Absent", "Present"),
        xname="Presence/Asence of fishing net", height=.18, )

#### Acoustic plots  ####
# BBPs
table <- cld(emmeans(mod.bbp, pairwise~acoustic, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(acoustic=table$acoustic,
                           letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, acoustic, BBPs_per_dolphin),
        myletters_df, acoustic, height=.9, ytitle="Mean number of BBPs per dolphin per min",
        old_names = c("AV","AV+D","D","D+AP","AP"),
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence")
# Buzz
table <- cld(emmeans(mod.buzz, pairwise~acoustic, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(acoustic=table$acoustic,
                           letter = trimws(table$.group))myletters_df <- data.frame(acoustic=c("AP","AV","AV+D","D","D+AP"),                                                                                   letter = c("a","a","a","a","a"))
#error, no acoustic in model:
myletters_df <- data.frame(acoustic=c("AP","AV","AV+D","D","D+AP"),
                           letter = c("a","a","a","a","a"))

barPlot(computeStats(bbp.dta, acoustic, Buzz_per_dolphin),
        myletters_df, acoustic, height=0.45, ytitle="Mean number of Buzzes per dolphin per min",
        old_names = c("AV","AV+D","D","D+AP","AP"),
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence")

# Burst-pulse
table <- cld(emmeans(mod.burst.pulse, pairwise~acoustic, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(acoustic=table$acoustic,
                           letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, acoustic, Burst.pulse_per_dolphin),
        myletters_df, acoustic, height=0.5, ytitle="Mean number of Burst-pulses per dolphin per min",
        old_names = c("AV","AV+D","D","D+AP","AP"),
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence")

#### Behaviour plots  ####
# BBPs
table <- cld(emmeans(mod.bbp, pairwise~behavior, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(acoustic=table$behavior,letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, behavior, BBPs_per_dolphin),
        myletters_df, behavior, height=1.2, ytitle="Mean number of BBPs per dolphin per min",
        old_names = c("CHAS", "DEPL", "SOCI"),
        new_names = c("Foraging", "Travelling", "Socialising"),
        xname="Behaviours of dolphins")
# Buzz
table <- cld(emmeans(mod.buzz, pairwise~behavior, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(acoustic=table$behavior,letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, behavior, Buzz_per_dolphin),
        myletters_df, behavior, height=1, ytitle="Mean number of Buzzes per dolphin per min",
        old_names = c("CHAS", "DEPL", "SOCI"),
        new_names = c("Foraging", "Travelling", "Socialising"),
        xname="Behaviours of dolphins")

# Burst-pulse
table <- cld(emmeans(mod.burst.pulse, pairwise~behavior, adjust="tukey"), Letters = letters)
myletters_df <- data.frame(acoustic=table$behavior,letter = trimws(table$.group))
barPlot(computeStats(bbp.dta, behavior, Burst.pulse_per_dolphin),
        myletters_df, behavior, height=0.4, ytitle="Mean number of Burst-pulses per dolphin per min",
        old_names = c("CHAS", "DEPL", "SOCI"),
        new_names = c("Foraging", "Travelling", "Socialising"),
        xname="Behaviours of dolphins")

#### Interaction : acoustic:fishing_net plots  ####
# BBP
letters_df <- computeLetters(emmeans(mod.bbp, pairwise~acoustic:fishing_net, adjust="tukey"), 
                             "fishing_net")
letters_df$acoustic <- computeLetters(emmeans(mod.bbp, pairwise~acoustic:fishing_net, adjust="tukey"), 
                                      "acoustic")$acoustic
letters_df <- letters_df[, c("acoustic","fishing_net","letter")]
letters_df$letter <- gsub(" ", "", letters_df$letter)
barPlot(computeStats(bbp.dta, fishing_net, BBPs_per_dolphin, two=acoustic),
        NULL, acoustic, fill=fishing_net,
        old_names = c("AV","AV+D","D","D+AP","AP"), ytitle="Mean number of BBPs per dolphin per min",
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence", height=c(1.6),
        colours=c("#E69F00","#999999"), size=5,
        legend_title="Fishing net", legend_labs=c("Present", "Absent"))

# Buzz
letters_df <- computeLetters(emmeans(mod.buzz, pairwise~acoustic:fishing_net, adjust="tukey"), 
                             "fishing_net")
letters_df$acoustic <- computeLetters(emmeans(mod.buzz, pairwise~acoustic:fishing_net, adjust="tukey"), 
                                      "acoustic")$acoustic
letters_df <- letters_df[, c("acoustic","fishing_net","letter")]
letters_df$letter <- gsub(" ", "", letters_df$letter)
barPlot(computeStats(bbp.dta, fishing_net, Buzz_per_dolphin, two=acoustic),
        NULL, acoustic, fill=fishing_net,
        old_names = c("AV","AV+D","D","D+AP","AP"), ytitle="Mean number of Buzzes per dolphin per min",
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence", height=c(0.77,0.77,0.8,0.77,0.77,0.8,0.77,0.8,0.8,0.8),
        colours=c("#E69F00","#999999"), size=5,
        legend_title="Fishing net", legend_labs=c("Present", "Absent"))

# Burst-pulse
letters_df <- computeLetters(emmeans(mod.burst.pulse, pairwise~acoustic:fishing_net, adjust="tukey"), 
                             "fishing_net")
letters_df$acoustic <- computeLetters(emmeans(mod.burst.pulse, pairwise~acoustic:fishing_net, adjust="tukey"), 
                                      "acoustic")$acoustic
letters_df <- letters_df[, c("acoustic","fishing_net","letter")]
letters_df$letter <- gsub(" ", "", letters_df$letter)
barPlot(computeStats(bbp.dta, fishing_net, Burst.pulse_per_dolphin, two=acoustic),
        NULL, acoustic, fill=fishing_net,
        old_names = c("AV","AV+D","D","D+AP","AP"), ytitle="Mean number of Burst-pulses per dolphin per min",
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence", height=c(0.9,0.85,0.9,0.9,0.85,0.9,0.85,0.9,0.85,0.85),
        colours=c("#E69F00","#999999"), size=5,
        legend_title="Fishing net", legend_labs=c("Present", "Absent"))

#### Interaction : acoustic:behavior plots  ####
# BBP
barPlot(computeStats(bbp.dta, behavior, BBPs_per_dolphin, two=acoustic),
        NULL, acoustic, fill=behavior,
        old_names = c("AV","AV+D","D","D+AP","AP"), ytitle="Mean number of BBPs per dolphin per min",
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence", 
        colours=c("#E69F00","#55c041", "#FF3814"), size=5,
        legend_title="Behaviour", legend_labs= c("Foraging", "Travelling", "Socialising"))

# Buzz
barPlot(computeStats(bbp.dta, behavior, Buzz_per_dolphin, two=acoustic),
        NULL, acoustic, fill=behavior,
        old_names = c("AV","AV+D","D","D+AP","AP"), ytitle="Mean number of Buzzes per dolphin per min",
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence", 
        colours=c("#E69F00","#55c041", "#FF3814"), size=5,
        legend_title="Behaviour", legend_labs= c("Foraging", "Travelling", "Socialising"))

# Burst-pulse
barPlot(computeStats(bbp.dta, behavior, Burst.pulse_per_dolphin, two=acoustic),
        NULL, acoustic, fill=behavior,
        old_names = c("AV","AV+D","D","D+AP","AP"), ytitle="Mean number of Burst-pulses per dolphin per min",
        new_names = c("BEF","BEF+DUR","DUR", "DUR+AFT", "AFT"),
        xname="Activation sequence", 
        colours=c("#E69F00","#55c041", "#FF3814"), size=5,
        legend_title="Behaviour", legend_labs= c("Foraging", "Travelling", "Socialising"))
