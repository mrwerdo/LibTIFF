#include "include/tiff.h"
#include "include/tiffconf.h"
#include "include/tiffio.h"
#include "include/tiffvers.h"

int TIFFGetField_uint32(TIFF *tif, ttag_t tag, uint32 *v) {
	return TIFFGetField(tif, tag, v);
}

int TIFFGetField_uint16(TIFF *tif, ttag_t tag, uint16 *v) {
	return TIFFGetField(tif, tag, v);
}

int TIFFSetField_uint32(TIFF *tif, ttag_t tag, uint32 v) {
	return TIFFSetField(tif, tag, v);
}

int TIFFSetField_uint16(TIFF *tif, ttag_t tag, uint16 v) {
	return TIFFSetField(tif, tag, v);
}

int TIFFSetField_ExtraSample(TIFF *tif, uint16 count, uint16 *types) {
	return TIFFSetField(tif, TIFFTAG_EXTRASAMPLES, count, types);
}

int TIFFGetField_ExtraSample(TIFF *tif, uint16 *count, uint16* types[]) {
    return TIFFGetField(tif, TIFFTAG_EXTRASAMPLES, count, types);
}
