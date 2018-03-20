# posterior predictive simulations
postpred <- function(post, sim) {
  N <- ncol(post$location)
  grab <- sample(4000, nsim)
  ppc <- list()
  for(jj in seq(nsim)) {
    gg <- grab[jj]
    oo <- c()
    for(ii in seq(N)) {
      oo[ii] <- rztnbinom(1, mu = post$location[gg, ii], theta = post$phi[gg])
    }
    ppc[[jj]] <- oo
  }
  ppc
}

# posterior predictive checks
# lots of internal IO
postchecks<- function(shelly, nsim, silent = FALSE) {
  load(paste0('../data/data_dump/diversity_image_', shelly, '.rdata'))
  pat <- paste0('trunc\\_[0-9]\\_', shelly)
  files <- list.files('../data/mcmc_out', pattern = pat, full.names = TRUE)
  fit <- read_stan_csv(files)
  if(!silent) {
    check_all_diagnostics(fit, max_depth = 15)
  }
  post <- rstan::extract(fit, permuted = TRUE)

  ppc <- postpred(post, nsim)

  # posterior predictive checks
  checks <- checks.single(standata$y, ppc)
  checks.time <- checks.group(standata$y, ppc, group = standata$t)
  out <- list(data = standata, post = post,
                    checks = checks, checks.time = checks.time)
  out
}




q75 <- function(x) quantile(x, 0.75)
q25 <- function(x) quantile(x, 0.25)

# internal checks
checks.single <- function(y, ppc) {
  ppc <- Reduce(rbind, ppc)

  # density
  ppc.dens <- ppc_dens_overlay(y, ppc[1:50, ])
  ppc.hist <- ppc_hist(y, ppc[1:5, ])

  # point estimates
  ppc.mean <- ppc_stat(y, ppc, stat = 'mean')
  ppc.sd <- ppc_stat(y, ppc, stat = 'sd')
  ppc.max <- ppc_stat(y, ppc, stat = 'max')
  #prop_zero <- function(x) mean(x == 0)
  #ppc.zero <- ppc_stat(y, ppc, stat = 'prop_zero')
  ppc.q25 <- ppc_stat(y, ppc, stat = 'q25')
  ppc.q75 <- ppc_stat(y, ppc, stat = 'q75')

  # error
  ppc.err <- ppc_error_scatter(y, ppc[1:6, ])
  ppc.avgerr <- ppc_error_scatter_avg(y, ppc)
  ppc.ecdf <- ppc_ecdf_overlay(y, ppc[1:50, ])

  # rootograms because i find them easy to read
  root.gg <- ppc_rootogram(y, ppc, style = 'hanging', prob = 0.8)

  # bars
  ppc.bars <- ppc_bars(y, ppc)

  # output
  out <- list(mean = ppc.mean, 
              sd = ppc.sd, 
              max = ppc.max, 
              #zero = ppc.zero, 
              q25 = ppc.q25,
              q75 = ppc.q75,
              err = ppc.err, 
              avgerr = ppc.avgerr, 
              ecdf = ppc.ecdf, 
              root = root.gg,
              bar = ppc.bars,
              dens = ppc.dens,
              hist = ppc.hist)
  out
}

# internal checks
checks.group <- function(y, ppc, group) {
  ppc <- Reduce(rbind, ppc)

  # by group
  ppc.bars.group <- ppc_bars_grouped(y, ppc, group = group)
  ppc.mean.group <- ppc_stat_grouped(y, ppc, group = group, stat = 'mean')
  ppc.sd.group <- ppc_stat_grouped(y, ppc, group = group, stat = 'sd')
  ppc.max.group <- ppc_stat_grouped(y, ppc, group = group, stat = 'max')
  ppc.q25.group <- ppc_stat_grouped(y, ppc, group = group, stat = 'q25')
  ppc.q75.group <- ppc_stat_grouped(y, ppc, group = group, stat = 'q75')
  ppc.avgerr.group <- ppc_scatter_avg_grouped(y, ppc, group = group)
  ppc.violin.group <- ppc_violin_grouped(y, ppc, group = group, 
                                         y_draw = 'points')

  # all the plots
  out <- list(bar.group = ppc.bars.group,
              mean.group = ppc.mean.group,
              sd.group = ppc.sd.group,
              max.group = ppc.max.group,
              q25.group = ppc.q25.group,
              q75.group = ppc.q75.group,
              avgerr.group = ppc.avgerr.group,
              violin.group = ppc.violin.group
              )
  out
}


# plot of diversity through time compared to mean estimated from posterior
# lots of io but puts out a plot
plot_divtime <- function(shelly, brks, vert) {
  midpoint <- apply(brks, 1, mean)
  # plot up unit div through time vs our estimate of average
  cc <- list()
  for(ii in seq(length(shelly))) {
    load(paste0('../data/data_dump/diversity_image_', shelly[ii], '.rdata'))
    cc[[ii]] <- data.frame(x = standata$t, y = standata$y, g = shelly[ii])
  }
  cc <- Reduce(rbind, cc)
  # put in terms of Mya
  cc$x <- mapvalues(cc$x, sort(unique(cc$x)), midpoint)

  cg <- ggplot(cc, aes(x = x, y = y)) 
  cg <- cg + geom_hline(yintercept = 0, colour = 'darkgrey')
  cg <- cg + geom_vline(xintercept = vert, alpha = 0.5, linetype = 'dashed')
  cg <- cg + geom_count(alpha = 0.5, 
                        position = position_jitter(width = 0.1, height = 0))
  cg <- cg + facet_grid(g ~ .)

  out <- list()
  for(ii in seq(length(shelly))) {
    load(paste0('../data/data_dump/diversity_image_', shelly[ii], '.rdata'))
    pat <- paste0('trunc\\_[0-9]\\_', shelly[ii])
    files <- list.files('../data/mcmc_out', pattern = pat, full.names = TRUE)
    fit <- read_stan_csv(files)
    post <- rstan::extract(fit, permuted = TRUE)
    pp <- postpred(post, nsim)

    by.time <- llply(pp, function(x) split(x, standata$t))
    mean.time <- llply(by.time, function(x) laply(x, mean))

    mean.time <- llply(mean.time, function(x) {
                         x <- cbind(x, seq(nrow(brks)))
                         x})

    mean.time <- Reduce(rbind, 
                        Map(function(x, y) 
                            cbind(x, y), mean.time, seq(nsim)))
    mean.time <- data.frame(mean.time, g = shelly[ii])
    names(mean.time) <- c('est', 'time', 'sim', 'g')
    out[[ii]] <- mean.time
  }
  mean.time <- Reduce(rbind, out)


  by.time <- group_by(mean.time, time, g)
  time.mean <- summarise(by.time, mean = mean(est), 
                         low = quantile(est, 0.1), 
                         high = quantile(est, 0.9))

  # put in terms of Mya
  time.mean$time <- mapvalues(time.mean$time, 
                              sort(unique(time.mean$time)), 
                              midpoint)
  cg <- cg + geom_pointrange(data = time.mean, 
                             mapping = aes(x = time, y = mean, 
                                           ymin = low, ymax = high),
                             colour = 'blue', size = 1.5, 
                             fatten = 2, alpha = 0.75)
  cg <- cg + scale_x_reverse()
  cg <- cg + labs(x = 'Time (Mya)', y = 'geological unit diversity')
  cg
}



# covariates through time
plot_covtime <- function(shelly, brks, covname, vert) {
  # covariate effects
  out <- out2 <- list()
  for(ii in seq(length(shelly))) {
    load(paste0('../data/data_dump/diversity_image_', shelly[ii], '.rdata'))
    pat <- paste0('trunc\\_[0-9]\\_', shelly[ii])
    files <- list.files('../data/mcmc_out', pattern = pat, full.names = TRUE)
    fit <- read_stan_csv(files)
    post <- rstan::extract(fit, permuted = TRUE)

    # covariates are : 
    #   intercept
    #   (max) thickness
    #   areal extent
    #   subsurface
    #   composition siliciclastic (carbonate is base)

    # violins
    mm <- melt(post$beta)
    mm[, 3] <- mapvalues(mm[, 3], unique(mm[, 3]), covname)
    names(mm) <- c('iter', 'time', 'covariate', 'value')
    mm$g <- shelly[ii]


    # point range
    betamean <- apply(post$beta, 2:3, mean)
    betalow <- apply(post$beta, 2:3, function(x) quantile(x, 0.1))
    betahigh <- apply(post$beta, 2:3, function(x) quantile(x, 0.9))
    betaest <- list(betamean, betalow, betahigh)
    betaest <- llply(betaest, function(x) {
                       colnames(x) <- covname
                       x})

    betaest <- llply(betaest, melt)
    betaest <- data.frame(betaest[[1]], 
                          low = betaest[[2]]$value, 
                          high = betaest[[3]]$value,
                          g = shelly[ii])
    names(betaest)[1:2] <- c('time', 'covariate')

    midpoint <- apply(brks, 1, mean)
    betaest$time <- mapvalues(betaest$time, 
                              sort(unique(betaest$time)), 
                              midpoint)
    mm$time <- mapvalues(mm$time, sort(unique(mm$time)), midpoint)

    out[[ii]] <- betaest
    out2[[ii]] <- mm
  }
  betaest <- Reduce(rbind, out)
  betaviol <- Reduce(rbind, out2)
  betaviol$covariate <- factor(betaviol$covariate, 
                               levels = levels(betaest$covariate))
  betaviol <- betaviol %>%
    group_by(covariate, g, time) %>%
    dplyr::mutate(p = sum(value > 0) / length(value)) %>%
    group_by()
  
  mg <- ggplot(betaest, aes(x = time, y = value))
  mg <- mg + geom_hline(yintercept = 0, colour = 'darkgrey')
  mg <- mg + geom_vline(xintercept = vert, alpha = 0.5, linetype = 'dashed')
  mg <- mg + geom_violin(data = betaviol, 
                         mapping = aes(x = time, y = value, group = time, 
                                       fill = p, colour = p), 
                         alpha = 0.5)
  mg <- mg + geom_pointrange(mapping = aes(ymin = low, ymax = high), fatten = 2)
  mg <- mg + facet_grid(g ~ covariate, scales = 'free_y')
  mg <- mg + scale_x_reverse()
  mg <- mg + scale_fill_distiller(name = 'Probability > 0', 
                                  palette = 'RdBu', limits = c(0, 1))
  mg <- mg + scale_colour_distiller(name = 'Probability > 0', 
                                    palette = 'RdBu', limits = c(0, 1))
  mg <- mg + labs(x = 'Time (Mya)', y = 'estimated regression coefficient')
  mg
}
