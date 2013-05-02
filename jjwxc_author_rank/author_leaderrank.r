## 计算绿晋江http://www.jjwxc.net作者的leaderrank
## pagerank 算法的wiki http://zh.wikipedia.org/wiki/pagerank
## leaderrank 算法的介绍 http://ishare.iask.sina.com.cn/f/24256966.html
## leaderrank 算法源码修改自此处的pagerank算法 http://www.wentrue.net/blog/?p=1258
## Licensed under the Apache License, Version 2.0

library(Matrix)


    load_data_pair <- function(link_file){
        data<-read.table(link_file, header=FALSE)
            names(data) <- c('from', 'to')
            fid <- unique(data$from)
            tid <- unique(data$to)
            uid <- sort(union(fid, tid))

            mlen <- length(uid)+1
            A <- Matrix(data=0, nrow=mlen, ncol=mlen)

            fidx <- match(data[[1]], uid, nomatch=0)
            tidx <- match(data[[2]], uid, nomatch=0)
            idx <- matrix(c(fidx, tidx), ncol=2)
            A[idx] <- 1

            A[mlen,]<- 1
            A[,mlen] <- 1

            return(list(A, uid))
    }


adjust_rank <- function(R, lt=0, ht=10){
    MIN_NUM <- 0.0000001
        if(min(R) == 0) R <- R+MIN_NUM
            R <- log(R)
                min_r <- min(R)
                max_r <- max(R)
                R <- (ht-lt)*(R - min_r)/(max_r-min_r) + lt
                return(R)
}

leaderrank <- function(A){
    N <- nrow(A) - 1
        K <- Diagonal(x=1/rowSums(A))
        M <- t(K %*% A)

        R0 <- matrix(1, nrow=N+1, ncol=1)
        R0[N+1,1] <- 0

        EPS <- 0.0001
        MAXITER <- 100 
        for(i in 1:MAXITER){
            R <- M %*% R0
                e <- sum(abs(R-R0))
                cat(paste('iteration', i, 'error', e), '\n')
                if(e < EPS) break
                    R0 <- R
        }

    sg <- R[N+1,1]/N
        Rsg <- matrix(sg, nrow=N+1, ncol=1)
        Rsg[N+1,1] <- 0
        R <- R + Rsg

        R <- as.vector(R)
        length(R) <- N
        R
}


ranking <- function(in_link, out_rank){
    ret <- load_data_pair(in_link)
        A <- ret[[1]]
        uid <- ret[[2]]
        pr <- leaderrank(A)
        pr <- adjust_rank(pr)
        ix <- sort(pr, index.return=TRUE, decreasing=TRUE)$ix
        out <- paste(seq(1, length(uid)), uid[ix], sprintf('%.4f', pr[ix]), sep=',')
        write.table(out, file=out_rank, quote=FALSE, col.names=FALSE, row.names=FALSE)
        pr
}

ranking('author_link.log', 'author_leaderrank.log')
