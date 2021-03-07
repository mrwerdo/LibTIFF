#ifndef _SWIFT_WRAPPER_
#define _SWIFT_WRAPPER_

#include "tiff.h"

/*
 * Functions to get a field.
 */
int TIFFGetField_uint32(TIFF *tif, ttag_t tag, uint32 *v);
int TIFFGetField_uint16(TIFF *tif, ttag_t tag, uint16 *v);

/*
 * Functions to set a field.
 */
int TIFFSetField_uint32(TIFF *tif, ttag_t tag, uint32 v);
int TIFFSetField_uint16(TIFF *tif, ttag_t tag, uint16 v);

/*
 * Sets & gets the extra sample field.
 * This is special, as it removes boilerplate from the swift code.
 */
int TIFFSetField_ExtraSample(TIFF *tif, uint16 count, uint16 *types);
int TIFFGetField_ExtraSample(TIFF *tif, uint16 *count, uint16 *types[]);

#endif /* _SWIFT_WRAPPER_ */
