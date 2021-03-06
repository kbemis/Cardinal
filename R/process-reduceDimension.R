
#### Dimension reduction methods ####
## ----------------------------------

setMethod("reduceDimension", signature = c(object = "MSImageSet", ref = "missing"),
	function(object, method = c("bin", "resample"),
		...,
		pixel = pixels(object),
		plot = FALSE)
	{
		.Deprecated_Cardinal1()
		fun <- reduceDimension.method(method)
		.message("reduceDimension: Using method = ", match.method(method))
		.time.start()
		mzout <- fun(numeric(nrow(object)), mz(object), ...)$t
		data <- pixelApply(object, function(s, ...) {
			reduceDimension.do(s, object, .Index, fun, plot, ...)$x
		}, .pixel=pixel, ..., .use.names=FALSE, .simplify=TRUE)
		feature <- features(object, mz=mzout)
		object@featureData <- object@featureData[feature,]
		object@pixelData <- object@pixelData[pixel,]
		object@imageData <- MSImageData(data=data,
			coord=coord(object@pixelData),
			storageMode=storageMode(imageData(object)),
			dimnames=list(
				featureNames(object@featureData),
				pixelNames(object@pixelData)))
		mz(object) <- mzout
		if ( match.method(method) == "peaks" ) {
			spectrumRepresentation(processingData(object)) <- "centroid"
			centroided(processingData(object)) <- TRUE
		}
		.message("reduceDimension: Done")
		.time.stop()
		object
	})

setMethod("reduceDimension", signature = c(object = "MSImageSet", ref = "numeric"),
	function(object, ref, method = "peaks", ...) {
		.Deprecated_Cardinal1()
		if ( min(ref) < min(mz(object)) || max(ref) > max(mz(object)) )
			.stop("reduceDimension: 'ref' contains m/z values outside of mass range.")
		reduceDimension(object, method=method, peaklist=ref, ...)
	})

setMethod("reduceDimension", signature = c(object = "MSImageSet", ref= "MSImageSet"),
	function(object, ref, method = "peaks", ...) {
		.Deprecated_Cardinal1()
		if ( !centroided(ref) )
			.stop("reduceDimension: 'ref' is not centroided. Run 'peakAlign' on it first.")
		object <- reduceDimension(object, method=method, ref=mz(ref), ...)
		peakPicking(processingData(object)) <- peakPicking(processingData(ref))
		object
	})

reduceDimension.do <- function(s, object, pixel, f, plot, ...) {
	sout <- f(s, mz(object), ...)
	if ( plot ) {
		wrap(plot(object, s ~ mz, pixel=pixel, col="gray",
			ylab="Intensity", strip=FALSE, ...),
			..., signature=f)
		wrap(points(sout$t, sout$x, col="red", pch=20, ...),
			..., signature=f)
		wrap(lines(sout$t, sout$x, col="red", type='h', lwd=0.5, ...),
			..., signature=f)
	}
	sout
}

reduceDimension.method <- function(method, name.only=FALSE) {
	if ( is.character(method) || is.null(method) ) {
		options <- c("bin", "resample", "peaks")
		method <- match.method(method, options)
		if ( name.only )
			return(method)
		method <- switch(method,
			bin = reduceDimension.bin,
			resample = reduceDimension.resample,
			peaks = reduceDimension.peaks,
			match.fun(method))
	}
	match.fun(method)
}

reduceDimension.bin <- function(x, t, width=200, offset=0, units=c("ppm", "mz"), fun="sum", ...) {
	units <- match.arg(units)
	if ( units == "ppm" ) {
		tout <- seq.ppm(from=offset + floor(min(t)), to=ceiling(max(t)), ppm=width / 2)
		width <- width * 1e-6 * tout  # ppm == half-bin-widths
	} else {
		tout <- seq(from=offset + floor(min(t)), to=ceiling(max(t)), by=width)
		width <- rep(width, length(tout)) # by == full-bin-widths
	}
	if ( length(tout) > length(t) )
		.stop("reduceDimension.bin: 'width' is too small.")
	lower <- 1L + findInterval(tout - width / 2, t, left.open=TRUE)
	upper <- findInterval(tout + width / 2, t, left.open=FALSE)
	xout <- binvec(x, lower, upper, method=fun)
	list(x=xout, t=tout)
}

reduceDimension.resample <- function(x, t, step=1, offset=0, ...) {
	tout <- seq(from=ceiling(min(t)), to=floor(max(t)), by=step) + offset
	if ( length(tout) > length(t) )
		.stop("reduceDimension.resample: 'step' is too small.")
	if ( offset < 0 ) {
		tout <- tout[-1]
	} else if ( offset > 0 ) {
		tout <- tout[-length(tout)]
	}
	xout <- interp1(x=t, y=x, xi=tout, method="linear", ...)
	list(x=xout, t=tout)
}

reduceDimension.peaks <- function(x, t, peaklist, type=c("area", "height"), ...) {
	if ( missing(peaklist) )
		.stop("reduceDimension.peaks: 'peaklist' required.")
	type <- match.arg(type)
	if ( type == "height" ) {
		method <- "max"
	} else if ( type == "area" ) {
		method <- "sum"
	}
	if ( length(peaklist) > length(t) )
		.stop("reduceDimension.peaks: 'peaklist' is too long.")
	bounds <- nearest_locmax(-x, peaklist)
	xout <- binvec(x, bounds[[1]], bounds[[2]], method=method)
	list(x=xout, t=peaklist)
}

