## 计算绿晋江http://www.jjwxc.net作者的pagerank （根据友情链接）
## pagerank 算法的wiki http://zh.wikipedia.org/wiki/PageRank
## pagerank 算法源码来自 http://www.wentrue.net/blog/?p=1258
## Licensed under the Apache License, Version 2.0

library(Matrix)


    load_data_pair <- function(link_file){
        data<-read.table(link_file, header=FALSE)
            names(data) <- c('from', 'to')
            fid <- unique(data$from)
            tid <- unique(data$to)
            uid <- sort(union(fid, tid))

            A <- Matrix(data=0, nrow=length(uid), ncol=length(uid))
            fidx <- match(data[[1]], uid, nomatch=0)
            tidx <- match(data[[2]], uid, nomatch=0)
            idx <- matrix(c(fidx, tidx), ncol=2)
            A[idx] <- 1

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

pagerank <- function(A){
    N <- nrow(A)
        K <- Diagonal(x=1/rowSums(A))
        M <- t(K %*% A)
        d <- 0.85
        C <- matrix((1-d)/N, nrow=N, ncol=1)

        R0 <- matrix(1/N, nrow=N, ncol=1)
        EPS <- 0.0001
        MAXITER <- 100
        for(i in 1:MAXITER){
            R <- d * M %*% R0 + C
                e <- sum(abs(R-R0))
                cat(paste('iteration', i, 'error', e), '\n')
                if(e < EPS) break
                    R0 <- R
        }
    R <- as.vector(R)
}

ranking <- function(in_link, out_file){
    ret <- load_data_pair(in_link)
        A <- ret[[1]]
        uid <- ret[[2]]
        pr <- pagerank(A)
        pr <- adjust_rank(pr)
        ix <- sort(pr, index.return=TRUE, decreasing=TRUE)$ix
        out <- paste(seq(1, length(uid)), uid[ix], sprintf('%.4f', pr[ix]), sep=',')
        write.table(out, file=out_file, quote=FALSE, col.names=FALSE, row.names=FALSE)
}


ranking('author_link.log',  'author_pagerank.log')
