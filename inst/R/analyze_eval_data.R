# BSD_2_clause
# Analysis of the monitoring data.

---
title: "ESA compliance with remotely sensed data"
author: "Tiffany Kim, Ya-Wei Li, and Jacob Malcom"
date: "`r Sys.Date()`"
output:
  rmarkdown::html_document:
  code_folding: hide
  css: custom.css
  df_print: kable
  fig_caption: yes
  fig_width: 7
  highlight: tango
  toc: true
  toc_depth: 3
  toc_float: true
---

library(dplyr)
library(ggplot2)
library(ggrepel)
library(ggthemes)
library(highcharter)
library(lubridate)
library(plotly)
library(readr)
library(readxl)
library(stringr)
library(tidyr)

source("multiplot.R")

###############################################################################
# Let's do some plotting and analysis!

basic_means <- function(dat) {
    cat(paste("mean action found",
              mean(dat$action_found, na.rm = TRUE),
              "\n"))
    cat(paste("mean action expected",
              mean(dat$reconcile, na.rm = TRUE),
              "\n"))
}
basic_means(form_dat)
basic_means(inform_dat)

make_expect_obs_hist <- function(dat) {
  values <- c("No", "Maybe", "Yes")
  exp <- table(dat$reconcile)
  obs <- table(dat$action_found)
  new <- data_frame(
    OE = c(rep("Observed", 3), rep("Expected", 3)),
    vals = c(values, values),
    freq = c(obs, exp)
  )
  ggplot(data = new, aes(x = vals, y = freq)) +
    geom_bar(stat = "identity") +
    labs(x = "Action observability",
         y = "# consultations") +
    facet_grid(. ~ OE) +
    theme_hc()

}
make_expect_obs_hist(form_dat)
make_expect_obs_hist(inform_dat)

form_dat$exp_obs <- ifelse(form_dat$reconcile == 1,
                           "Observable",
                           ifelse(form_dat$reconcile == 0.5,
                                  "Maybe",
                                  "Not observeable"))
ggplot(data = form_dat, aes(factor(exp_obs))) +
    geom_bar()

# Now let's look by work cat and type
scatter_and_violin_work_cat <- function(dat) {
    plt <- ggplot(dat, aes(factor(work_category), action_found)) +
           geom_violin(fill = "#D1E9D6", colour = "white") +
           geom_jitter(width = 0.3, height = 0.05, alpha = 0.2, size = 2) +
           labs(x = "",
                y = "No <--- Action found? ---> Yes") +
           theme(axis.text.x = element_text(angle = 40, hjust = 1)) +
           theme_hc()
    plt
}

multiplot(scatter_and_violin_work_cat(form_dat),
          scatter_and_violin_work_cat(inform_dat),
          cols = 1)

scatter_and_violin_work_type <- function(dat) {
    plt <- ggplot(dat, aes(factor(work_type), action_found)) +
           geom_violin(fill = "#D1E9D6", colour = "white") +
           geom_jitter(width = 0.3, height = 0.05, alpha = 0.3, size = 4) +
           labs(x = "",
                y = "No              <--- Action found? --->              Yes") +
           theme(axis.text.x = element_text(angle = 25, hjust = 1)) +
           theme_hc()
    plt
}

multiplot(scatter_and_violin_work_type(form_dat),
          scatter_and_violin_work_type(inform_dat),
          cols = 1)

# habitat change categories by formal
trans_hab <- function(x) {
    if (is.na(x) | is.null(x)) NA
    else if (x == 1) "nat -> nat"
    else if (x == 2) "nat -> ag"
    else if (x == 3) "nat -> dev"
    else if (x == 4) "ag -> dev"
    else "dev -> dev"
}

q <- c(1, 2, 1, 3, NA)
w <- sapply(q, trans_hab)

tmp <- sapply(combo_dat$hab_chg, trans_hab)
table(tmp, combo_dat$formal_in)


# Curious about the distribution of earliest image dates:
mean(form_dat$earliest_date, na.rm = T)
median(form_dat$earliest_date, na.rm = T)
summary(form_dat$earliest_date, na.rm = T)

hist(form_dat$earliest_date,
     xlab = "Earliest image date",
     ylab = "Frequency",
     main = "",
     freq = TRUE,
     col = "gray50",
     border = "white",
     breaks = "years")

ggplot(combo_dat, aes(earliest_date)) +
    geom_histogram(colour="white") +
    labs(x = "Earliest Aerial Image Date") +
    theme_hc()

# observability by FY
ggplot(data = combo_dat, aes(x = factor(FY), y = action_found, colour = formal_in)) +
    geom_violin(fill = viridis(1), alpha = 0.3) +
    geom_jitter(alpha = 0.3, height = 0.1, size = 3) +
    labs(x = "", y = "No  <--  Action found?  -->  Yes") +
    theme_hc()

###########################################################################
# OK, we want to get an overview of observeabilities:
get_observabilities <- function(dat, formal_in) {
    type_mean <- tapply(dat$action_found,
                        INDEX = dat$work_type,
                        FUN = mean, na.rm = TRUE)
    type_median <- tapply(dat$action_found,
                        INDEX = dat$work_type,
                        FUN = median, na.rm = TRUE)
    if (formal_in == "formal") {
        type_count <- tapply(dat$N_formal,
                             INDEX = dat$work_type,
                             FUN = mean, na.rm = TRUE)
    } else {
        type_count <- tapply(dat$N_consultations,
                             INDEX = dat$work_type,
                             FUN = mean, na.rm = TRUE)
    }
    expect_to_see_all <- type_mean * type_count

    # And these are the results at the highest level:
    tot_num_formal <- sum(type_count, na.rm = TRUE)
    exp_num_see <- sum(expect_to_see_all, na.rm = TRUE)
    cat(paste("Observability:\n\t", exp_num_see / tot_num_formal, "\n"))
    cat(paste("# consultations in set:\n\t", tot_num_formal, "\n"))
    cat(paste("# consultations we expect to see effects:\n\t", exp_num_see, "\n"))
}

get_observabilities(form_dat, "formal")
get_observabilities(inform_dat, "informal")

# dat = the dplyr'd formal/informal data; cons_dat = formal/informal consult data
make_scatter_df <- function(dat, cons_dat, formal_in) {
    type_mean <- tapply(dat$action_found,
                        INDEX = dat$work_type,
                        FUN = mean, na.rm = TRUE)
    type_median <- tapply(dat$action_found,
                        INDEX = dat$work_type,
                        FUN = median, na.rm = TRUE)
    if (formal_in == "formal") {
        type_count <- tapply(dat$N_formal,
                             INDEX = dat$work_type,
                             FUN = mean, na.rm = TRUE)
    } else {
        type_count <- tapply(dat$N_consultations,
                             INDEX = dat$work_type,
                             FUN = mean, na.rm = TRUE)
    }
    expect_to_see_all <- type_mean * type_count

    tmp_dat <- data.frame(type_count = as.vector(type_count),
                          type_mean = as.vector(type_mean),
                          work = names(type_count))
    work_cat_type <- data.frame(cat = cons_dat$work_category,
                                work = as.character(cons_dat$work_type))
    work_cat_type$uniq <- duplicated(work_cat_type$work)
    work_cat_type <- work_cat_type[work_cat_type$uniq == FALSE, ]
    tmp_dat <- inner_join(tmp_dat, work_cat_type, by = "work")
    return(tmp_dat)
}

form_obs_dat <- make_scatter_df(form_dat, form_cons, "formal")
inform_obs_dat <- make_scatter_df(inform_dat, inform_cons, "informal")

plot_observability_vs_available <- function(dat) {
    plt <- ggplot(dat, aes(type_mean, type_count)) +
           geom_jitter(width = 0, height = 0.1, alpha = 0.3, size = 4) +
           geom_label_repel(aes(type_mean,
                                type_count,
                                fill = factor(cat),
                                label = str_wrap(work, width = 30)),
                           size = 2,
                           show.legend = FALSE) +
           labs(x = "Mean success rate",
                y = "# consultations in work type") +
           theme_hc()
    plt
}

plot_observability_vs_available(form_obs_dat)
plot_observability_vs_available(inform_obs_dat)

plot_ly(form_obs_dat,
        type = "scatter",
        mode = "markers",
        x = type_count,
        y = type_mean,
        text = paste("Work type:", work, "<br>Work category:", cat),
        marker = list(color = substr(viridis(n = length(unique(form_obs_dat$cat))), 0, 7),
                      opacity = 0.6,
                      size = 20)) %>%
layout(xaxis = list(title = "# actions"),
       yaxis = list(title = "Prop. observed"))

###########################################################################
# Wonder how the mean area changes with sample size

mean_samp <- function(x) {
    medians <- vector()
    means <- vector()
    ns <- vector()
    for (i in c(10, 20, 50, 75, 100, 150)) {
        for (j in 1:100) {
            cur_samp <- sample(x, i)
            cur_mean <- mean(cur_samp, na.rm = TRUE)
            cur_median <- median(cur_samp, na.rm = TRUE)
            medians <- c(medians, cur_median)
            means <- c(means, cur_mean)
            ns <- c(ns, i)
        }
    }
    res <- data.frame(ns, means, medians)
    return(res)
}

form_mean_Ns <- mean_samp(form_dat$area)
inform_mean_Ns <- mean_samp(inform_dat$area)

aplt <- ggplot(data = form_mean_Ns, aes(x = factor(ns), y = means)) +
        geom_violin(fill = "lightsteelblue") +
        geom_hline(yintercept = mean(form_dat$area, na.rm=TRUE),
                   color = "red") +
        labs(x = "Sample Size",
             y = "Mean area",
             title = "Formal") +
        theme_hc()
bplt <- ggplot(data = inform_mean_Ns, aes(x = factor(ns), y = means)) +
        geom_violin(fill = "lightsteelblue") +
        geom_hline(yintercept = mean(inform_dat$area, na.rm=TRUE),
                   color = "red") +
        labs(x = "Sample Size",
             y = "",
             title = "Informal") +
        theme_hc()
multiplot(aplt, bplt, cols = 2)

###########################################################################
# Let's look for some other differences, if any
check_area_disturbed <- function(dat) {
    fdat <- dat[dat$formal_in == "formal", ]
    idat <- dat[dat$formal_in == "informal", ]
    formal_area_mean <- mean(fdat$area, na.rm = T)
    informal_area_mean <- mean(idat$area, na.rm = T)
    formal_area_median <- median(fdat$area, na.rm = T)
    informal_area_median <- median(idat$area, na.rm = T)
    formal_area_sd <- sd(fdat$area, na.rm = T)
    informal_area_sd <- sd(idat$area, na.rm = T)
    formal_area_n <- sum(!is.na(fdat$area))
    informal_area_n <- sum(!is.na(idat$area))
    formal_area_se <- formal_area_sd / sqrt(formal_area_n)
    informal_area_se <- informal_area_sd / sqrt(informal_area_n)
    formal_start_date_mean <- mean(fdat$start_date, na.rm = T)
    informal_start_date_mean <- mean(idat$start_date, na.rm = T)
    formal_start_date_sd <- sd(fdat$start_date, na.rm = T)
    informal_start_date_sd <- sd(idat$start_date, na.rm = T)

    formal_FWS_concl_date_mean <- mean(fdat$FWS_concl_date, na.rm = T)
    informal_FWS_concl_date_mean <- mean(idat$FWS_concl_date, na.rm = T)
    formal_FWS_concl_date_sd <- sd(fdat$FWS_concl_date, na.rm = T)
    informal_FWS_concl_date_sd <- sd(idat$FWS_concl_date, na.rm = T)
    formal_lat_mean <- mean(fdat$lat_dec_deg.x, na.rm = T)
    informal_lat_mean <- mean(idat$lat_dec_deg.x, na.rm = T)
    formal_lat_sd <- sd(fdat$lat_dec_deg.x, na.rm = T)
    informal_lat_sd <- sd(idat$lat_dec_deg.x, na.rm = T)
    formal_long_mean <- mean(fdat$long_dec_deg.x, na.rm = T)
    informal_long_mean <- mean(idat$long_dec_deg.x, na.rm = T)
    formal_long_sd <- sd(fdat$long_dec_deg.x, na.rm = T)
    informal_long_sd <- sd(idat$long_dec_deg.x, na.rm = T)

    variable <- c("area", "area", "area", "area", "area",
                  "start date", "end date",
                  "latitude", "latitude",
                  "longitude", "longitude")
    stat <- c("mean", "sd", "median", "n", "se",
              "mean", "mean", rep(c("mean", "sd"), 2))
    print(stat)
    formal <- c(prettyNum(formal_area_mean, digits = 3),
                prettyNum(formal_area_sd, digits = 3),
                prettyNum(formal_area_median, digits = 3),
                prettyNum(formal_area_n, digits = 3),
                prettyNum(formal_area_se, digits = 3),
                format(formal_start_date_mean, format = "%d %b %Y"),
                format(formal_FWS_concl_date_mean, format = "%d %b %Y"),
                prettyNum(formal_lat_mean, digits = 3),
                prettyNum(formal_lat_sd, digits = 3),
                prettyNum(formal_long_mean, digits = 3),
                prettyNum(formal_long_sd, digits = 3))

    informal <- c(prettyNum(informal_area_mean, digits = 3),
                  prettyNum(informal_area_sd, digits = 3),
                  prettyNum(informal_area_median, digits = 3),
                  prettyNum(informal_area_n, digits = 3),
                  prettyNum(informal_area_se, digits = 3),
                  format(informal_start_date_mean, format = "%d %b %Y"),
                  format(informal_FWS_concl_date_mean, format = "%d %b %Y"),
                  prettyNum(informal_lat_mean, digits = 3),
                  prettyNum(informal_lat_sd, digits = 3),
                  prettyNum(informal_long_mean, digits = 3),
                  prettyNum(informal_long_sd, digits = 3))

    result <- data.frame(variable, stat, formal, informal)
    result
}

summary_stats <- check_area_disturbed(combo_dat)
summary_stats

amod1 <- lm(log(combo_dat$area + 0.01) ~ combo_dat$formal_in)
summary(amod1)
hist(resid(amod1))

amod2 <- lm(combo_dat$area ~ combo_dat$long_dec_deg.x)
summary(amod2)

ggplot(combo_dat, aes(area, fill = formal_in, colour = formal_in)) +
    geom_density(alpha = 0.3) +
    theme_hc()


###############################################################################
# Estimate total area

bootstrap_total_area <- function(dat, B = 1000, N) {
    areas <- dat[!is.na(dat$area) & (dat$hab_chg == 2 |
                                     dat$hab_chg == 3 |
                                     dat$hab_chg == 4), ]$area
    samp_reps <- rep(NA, B)
    for (i in 1:B) {
        samp_reps[i] <- sum(sample(areas, replace = TRUE, size = N), na.rm=TRUE)
    }
    samp_df <- data.frame(samp_reps)

    plt <- ggplot(samp_df, aes(samp_reps)) +
               geom_histogram(colour = "white") +
               labs(x = "Sum of sampled areas (acres)",
                    y = "Frequency") +
               theme_hc()
    print(plt)

    print(mean(samp_reps))
    print(quantile(probs = c(0.025, 0.975), samp_reps, na.rm = TRUE))
    return(samp_df)
}

form_boot <- bootstrap_total_area(form_dat, B=10000, N=6829)
inform_boot <- bootstrap_total_area(inform_dat, B=10000, N=81461)

bootstrap_forest_area <- function(dat, B = 1000, N) {
    areas <- dat[!is.na(dat$area) & dat$work_category == "forestry"
                 & (dat$hab_chg == 2 |
                    dat$hab_chg == 3 |
                    dat$hab_chg == 4), ]$area
    samp_reps <- rep(NA, B)
    for (i in 1:B) {
        samp_reps[i] <- sum(sample(areas, replace = TRUE, size = N))
    }
    samp_df <- data.frame(samp_reps)

    plt <- ggplot(samp_df, aes(samp_reps)) +
               geom_histogram(colour = "white") +
               labs(x = "Sum of sampled areas (ha)",
                    y = "Frequency") +
               theme_hc()
    print(plt)

    print(mean(samp_reps))
    print(quantile(probs = c(0.025, 0.975), samp_reps))
    return(samp_df)
}

form_boot <- bootstrap_forest_area(form_dat, B=10000, N=361)
inform_boot <- bootstrap_total_area(inform_dat, B=10000, N=81461)


boots <- data.frame(formal = form_boot$samp_reps, informal = inform_boot$samp_reps)
head(boots)
boots$total <- boots$form + boots$inform
boots$total_ha <- boots$total * 0.404686

boot2 <- boots[,1:2] %>% gather()
names(boot2) <- c("type", "area")

plt <- ggplot(boot2, aes(area, fill = type)) +
           geom_histogram(bins = 100) +
           labs(x = "\nSum of sampled areas (acres)",
                y = "Frequency\n") +
           scale_fill_viridis(discrete = TRUE,
                              guide = guide_legend(title = "Consult. type")) +
           theme_hc() +
           theme(legend.position = "right",
                 legend.title = element_text(size = 8),
                 legend.text = element_text(size = 8))
print(plt)

## Am going to need to figure out how to weight the samples by prob coords.
mod1 <- lm(area ~ ESOffice.x, data = form_dat)
summary(mod1)
hist(resid(mod1))

mod2 <- lm(area ~ ESOffice.x, data = inform_dat)
summary(mod2)
hist(resid(mod2))
anova(mod2)

## Turns out, no. There is no significant relationship, so I don't think more
## complex sampling is warranted.


mod1 <- lm(area ~ work_category, data = form_dat)
summary(mod1)
hist(resid(mod1))

mod2 <- lm(area ~ work_category, data = inform_dat)
summary(mod2)
hist(resid(mod2))

ggplot(data = form_dat, aes(x = factor(work_category), y = area)) +
    geom_boxplot() +
    labs(x = "", y = "Area (ha)") +
    theme(axis.text.x = element_text(angle = 40, hjust = 1)) +
    theme_hc()

ggplot(data = inform_dat, aes(x = factor(work_category), y = area)) +
    geom_boxplot() +
    labs(x = "", y = "Area (ha)") +
    theme(axis.text.x = element_text(angle = 40, hjust = 1)) +
    theme_hc()

