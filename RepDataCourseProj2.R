#load libraries
library(plyr)
library(dplyr)
library(knitr)
library(ggplot2)
library(gridExtra)

#set WD
setwd("S:/Documents/R/Reproducible_Research2")

#download data from the url ("https://d396qusza40orc.cloudfront.net/repdata%2Fdata%2FStormData.csv.bz2") & check if file exists
if(!file.exists("StormData.bz2")) {
        url <- "https://d396qusza40orc.cloudfront.net/repdata%2Fdata%2FStormData.csv.bz2"
        download.file(url, destfile="StormData.bz2", method = "libcurl")
}

#load data 
data <- read.csv("StormData.bz2", stringsAsFactors = FALSE, strip.white=TRUE, header=TRUE)

#retain only relevant data
relevantData <- data[ , c("EVTYPE", "BGN_DATE", "FATALITIES", "INJURIES", "PROPDMG", "PROPDMGEXP", "CROPDMG", "CROPDMGEXP")]
#display structure
str(relevantData)

#cleanse date field & shave off hour / minutes / seconds
relevantData$BGN_DATE <- as.Date(relevantData$BGN_DATE,"%m/%d/%Y")
str(relevantData$BGN_DATE)

#create clear costs of damages by concatenating propdmg & cropdmg with the exponent variables
#propdmg -- show exponents
sort(table(relevantData$PROPDMGEXP), decreasing = TRUE)
#cropdmg -- show exponents
sort(table(relevantData$CROPDMGEXP), decreasing = TRUE)

#K = thousands, M = millions, B = billions - explained on pg 12 - https://d396qusza40orc.cloudfront.net/repdata%2Fpeer2_doc%2Fpd01016005curr.pdf
#first create clean PROPDMGEXP & CROPDMGEXP var to create numeric exponents for billions, millions, thousands, hundreds & specifically listed exponents

cleanPROPDMGEXP <- mapvalues(relevantData$PROPDMGEXP,
                         c("K","M","", "B","m","+","0","5"),
                         c(1e3,1e6, 1, 1e9,1e6,  1,  1,1e5))

cleanCROPDMGEXP <- mapvalues(relevantData$CROPDMGEXP,
                         c("","M","K","m","B","?"),
                         c( 1,1e6,1e3,1e6,1e9,1))

#display new variable summary & confirm consistent conversions
sort(table(cleanPROPDMGEXP), decreasing = TRUE)
sort(table(cleanCROPDMGEXP), decreasing = TRUE)

#add variable to dataset based on PROPDMG & the new numeric exponentvariable
relevantData$totalPROPDMG <- as.numeric(cleanPROPDMGEXP) * relevantData$PROPDMG
relevantData$totalCROPDMG <- as.numeric(cleanCROPDMGEXP) * relevantData$CROPDMG

#remove new variables
remove(cleanPROPDMGEXP)
remove(cleanCROPDMGEXP)

#display summary of the costs
summary(relevantData$totalPROPDMG)
summary(relevantData$totalCROPDMG)

#show revised / clean dataset after removing old propdmg / cropdmg and exponent variables
cleanData <- relevantData[ , c("EVTYPE", "BGN_DATE", "FATALITIES", "INJURIES", "totalPROPDMG", "totalCROPDMG")]
str(cleanData)
head(cleanData)

#plot histogram to display the spread from what time this data was recorded
#strip year only from date field
cleanData$years <- as.numeric(format(cleanData$BGN_DATE, "%Y"))
summary(cleanData$years)

#create plot
p <- ggplot(cleanData, aes(x = years)) +
  geom_histogram(aes(fill = ..count..), binwidth = 1) + 
  ggtitle(label = "Dispersion of Data Collection", subtitle = "Spread of Events Recorded Between 1950 - 1995") +
  scale_x_continuous(name = "Years", breaks = seq(1950, 1995, 9), limits=c(1950,1995)) +
  scale_y_continuous(name = "Number of Events Recorded") +
  scale_fill_gradient("Events Recorded", low = "grey80", high = "dodgerblue3")

print(p)

# Question 1: Across the United States, which types of events (as indicated in the EVTYPE variable) are 
# most harmful with respect to population health?

#subset dataset to display only the fatalities & injuries for each event
fatalities <- aggregate(FATALITIES ~ EVTYPE, data = cleanData, FUN = sum)
injuries <- aggregate(INJURIES ~ EVTYPE, data = cleanData, FUN = sum)

#find top 10 most harmful for each category
#fatalities
#sort data frame in decreasing order and use head function to retain only top 10
fatalities <- fatalities[order(fatalities$FATALITIES, decreasing=TRUE),] 
fatalities <- head(fatalities, 6)

#injuries
#sort data frame in decreasing order and use head function to retain only top 10
injuries <- injuries[order(injuries$INJURIES, decreasing=TRUE),] 
injuries <- head(injuries, 6)

#create plot for fatalities
p1 <- ggplot(data = fatalities, aes(x = reorder(EVTYPE, -FATALITIES), y = FATALITIES, fill = EVTYPE)) +
  geom_bar(stat = "identity") +
  ggtitle(label = "Total Fatalities by Event Type", subtitle = "Top 6 Events from 1950-1995 in the Storm Database") +
  xlab("") + ylab("Fatalities Recorded") + 
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  geom_text(aes(label = FATALITIES))

#create plot for injuries
p2 <- ggplot(data = injuries, aes(x = reorder(EVTYPE, -INJURIES), y = INJURIES, fill = EVTYPE)) +
  geom_bar(stat = "identity") +
  ggtitle(label = "Total Injuries by Event Type", subtitle = "Top 6 Events from 1950-1995 in the Storm Database") +
  xlab("Event Type") + ylab("Injuries Recorded") + 
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  geom_text(aes(label = INJURIES)) 


# prep background for two plots - fatalities & injuries
grid.arrange(p1, p2, ncol = 1, heights = c(4,4))

# Question 2: Across the United States, which types of events have the greatest economic consequences?
#create new dataset to display aggregate damages by event
propdmg <- aggregate(totalPROPDMG ~ EVTYPE, data = cleanData, FUN = sum)
cropdmg <- aggregate(totalCROPDMG ~ EVTYPE, data = cleanData, FUN = sum)
economicDmg <- merge(propdmg, cropdmg, by.x = "EVTYPE")

#find top sources of prop and crop dmg
topPropDmg <- economicDmg[order(economicDmg$totalPROPDMG, decreasing=TRUE),]
topCropDmg <- economicDmg[order(economicDmg$totalCROPDMG, decreasing=TRUE),]

#filter to top 6 of each source and add label of damage type
topPropDmg <- head(topPropDmg, 6)
topPropDmg$Type <- "Property"
topPropDmg <- topPropDmg[,c("EVTYPE", "totalPROPDMG", "Type")]
topCropDmg <- head(topCropDmg, 6)
topCropDmg$Type <- "Crop"
topCropDmg <- topCropDmg[,c("EVTYPE", "totalCROPDMG", "Type")]

#merge top 6 sources of crop and prop dmg to new dataframe and create final variable called Damages which shows damages of top 6 sources of each
topEconomicDMG <- merge(topCropDmg, topPropDmg, all.x = TRUE, all.y = TRUE)
topEconomicDMG <- topEconomicDMG %>%
  rowwise() %>% 
  mutate(Damages = sum(totalCROPDMG, totalPROPDMG, na.rm = TRUE))


#create and print bar chart
p3 <- ggplot(data = topEconomicDMG, aes(x = reorder(EVTYPE, -Damages), y = Damages, fill = Type)) + 
  geom_bar(stat = "identity") + 
  ggtitle("Total Economic Damages by Event Type") + xlab("Event Type") + ylab("Damages (in US Dollars)") +
  theme(axis.text.x = element_text(angle=45, hjust=1))

print(p3)
