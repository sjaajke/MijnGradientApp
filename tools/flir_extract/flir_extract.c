/**
 * flir_extract - Multi-command tool for FLIR radiometric image manipulation.
 *
 * Uses the Teledyne FLIR Atlas C SDK.  Each command outputs JSON to stdout.
 *
 * Commands:
 *   info   <image>                                 Extract metadata + spots
 *   render <image> <out.png> [palette] [colorDist] [scaleMin] [scaleMax]
 *   set-palette  <image> <out.png> <preset>
 *   set-scale    <image> <out.png> <min> <max> [palette]
 *   set-colordist <image> <out.png> <mode> [palette]
 *   move-spot    <image> <out.png> <id> <newX> <newY>
 *   remove-spot  <image> <out.png> <id>
 *   add-spot     <image> <out.png> <x> <y>
 *   add-rect     <image> <out.png> <x> <y> <w> <h>
 *   add-ellipse  <image> <out.png> <cx> <cy> <rx> <ry>
 *   add-line     <image> <out.png> <x1> <y1> <x2> <y2>
 *   add-isotherm <image> <out.png> <type> <temp1> [temp2]
 *   set-params   <image> <out.png> <emissivity> <distance> <reflectedT> <humidity>
 *   get-temp     <image> <x> <y>
 *   save         <image> <out_path> [format]
 */

#include <acs/thermal_image.h>
#include <acs/renderer.h>
#include <acs/palette.h>
#include <acs/isotherms.h>
#include <acs/measurement_spot.h>
#include <acs/measurement_shape.h>
#include <acs/measurement_rectangle.h>
#include <acs/measurement_ellipse.h>
#include <acs/measurement_line.h>
#include <acs/measurement_marker.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── Error handling ─────────────────────────────────────────────────────── */

static int check_error(void)
{
    ACS_Error err = ACS_getLastError();
    if (err.code) {
        ACS_String *msg = ACS_getErrorMessage(err);
        fprintf(stderr, "SDK error: %s (%s)\n",
                msg ? ACS_String_get(msg) : "?", ACS_getLastErrorMessage());
        if (msg) ACS_String_free(msg);
        return 1;
    }
    return 0;
}

static void fail_json(const char *error, const char *message)
{
    printf("{ \"ok\": false, \"error\": \"%s\", \"message\": \"%s\" }\n", error, message);
}

/* ── Image open / close helpers ─────────────────────────────────────────── */

static ACS_ThermalImage *open_image(const char *path)
{
    ACS_NativeString *ns = ACS_NativeString_createFrom(path);
    ACS_ThermalImage *img = ACS_ThermalImage_alloc();
    ACS_ThermalImage_openFromFile(img, ACS_NativeString_get(ns));
    ACS_NativeString_free(ns);
    if (check_error()) { ACS_ThermalImage_free(img); return NULL; }
    ACS_ThermalImage_setTemperatureUnit(img, ACS_TemperatureUnit_celsius);
    return img;
}

/* ── Render to raw RGBA file (headerless) ───────────────────────────────── */

static int write_ppm(const char *outPath, const unsigned char *data,
                     int w, int h, int stride, int bpp)
{
    /* Write PPM (P6) – universally readable, simple */
    FILE *f = fopen(outPath, "wb");
    if (!f) { fprintf(stderr, "Cannot write %s\n", outPath); return 1; }
    fprintf(f, "P6\n%d %d\n255\n", w, h);
    for (int y = 0; y < h; ++y) {
        const unsigned char *row = data + y * stride;
        for (int x = 0; x < w; ++x) {
            /* RGBA → RGB */
            fputc(row[x * bpp + 0], f);
            fputc(row[x * bpp + 1], f);
            fputc(row[x * bpp + 2], f);
        }
    }
    fclose(f);
    return 0;
}

/* Save FLIR metadata back to the original file (preserves radiometric data). */
static void save_flir_inplace(ACS_ThermalImage *img, const char *origPath)
{
    ACS_NativeString *ns = ACS_NativeString_createFrom(origPath);
    ACS_ThermalImage_saveAs(img, ACS_NativeString_get(ns), ACS_FileFormat_jpeg);
    ACS_NativeString_free(ns);
}

static int render_to_file(ACS_ThermalImage *img, const char *outPath)
{
    ACS_ImageColorizer *col = ACS_ImageColorizer_alloc(img);
    if (check_error()) return 1;

    ACS_Renderer *ren = ACS_Colorizer_asRenderer(ACS_ImageColorizer_asColorizer(col));
    ACS_Renderer_setOutputColorSpace(ren, ACS_ColorSpaceType_rgba);
    ACS_Renderer_update(ren);
    if (check_error()) { ACS_ImageColorizer_free(col); return 1; }

    const ACS_ImageBuffer *buf = ACS_Renderer_getImage(ren);
    int w      = ACS_ImageBuffer_getWidth(buf);
    int h      = ACS_ImageBuffer_getHeight(buf);
    int stride = ACS_ImageBuffer_getStride(buf);
    int bpp    = ACS_ImageBuffer_getBytesPerPixel(buf);
    const unsigned char *pixels = ACS_ImageBuffer_getData(buf);

    int rc = write_ppm(outPath, pixels, w, h, stride, bpp);
    ACS_ImageColorizer_free(col);
    return rc;
}

/* ── Palette preset by name ─────────────────────────────────────────────── */

typedef struct { const char *name; int value; } NamedPreset;
static const NamedPreset palette_presets[] = {
    { "arctic",    ACS_PalettePreset_arctic },
    { "blackhot",  ACS_PalettePreset_blackhot },
    { "bw",        ACS_PalettePreset_bw },
    { "coldest",   ACS_PalettePreset_coldest },
    { "colorwheel",ACS_PalettePreset_colorWheelRedhot },
    { "colorwheel12", ACS_PalettePreset_colorWheel12 },
    { "colorwheel6",  ACS_PalettePreset_colorWheel6 },
    { "doublerainbow", ACS_PalettePreset_doubleRainbow2 },
    { "hottest",   ACS_PalettePreset_hottest },
    { "iron",      ACS_PalettePreset_iron },
    { "lava",      ACS_PalettePreset_lava },
    { "rainbow",   ACS_PalettePreset_rainbow },
    { "rainhc",    ACS_PalettePreset_rainHC },
    { "whitehot",  ACS_PalettePreset_whitehot },
    { NULL, 0 }
};

static int palette_by_name(const char *name)
{
    for (const NamedPreset *p = palette_presets; p->name; ++p)
        if (strcasecmp(p->name, name) == 0) return p->value;
    return ACS_PalettePreset_iron; /* default */
}

/* ── Color distribution mode by name ────────────────────────────────────── */

typedef struct { const char *name; int value; } NamedMode;
static const NamedMode colordist_modes[] = {
    { "linear",    ACS_ColorDistribution_temperatureLinear },
    { "histogram", ACS_ColorDistribution_histogramEqualization },
    { "signal",    ACS_ColorDistribution_signalLinear },
    { "plateau",   ACS_ColorDistribution_plateauHistogramEqualization },
    { "dde",       ACS_ColorDistribution_dde },
    { "entropy",   ACS_ColorDistribution_entropy },
    { "ade",       ACS_ColorDistribution_ade },
    { "fsx",       ACS_ColorDistribution_fsx },
    { "lce",       ACS_ColorDistribution_lce },
    { NULL, 0 }
};

static int colordist_by_name(const char *name)
{
    for (const NamedMode *m = colordist_modes; m->name; ++m)
        if (strcasecmp(m->name, name) == 0) return m->value;
    return ACS_ColorDistribution_temperatureLinear;
}

/* ── Print measurement area stats ───────────────────────────────────────── */

static void print_marker_json(const ACS_MeasurementMarker *marker)
{
    ACS_ThermalValue minV = ACS_MeasurementMarker_getMinValue(marker);
    ACS_ThermalValue maxV = ACS_MeasurementMarker_getMaxValue(marker);
    ACS_ThermalValue avgV = ACS_MeasurementMarker_getAvgValue(marker);
    printf("  \"min\": %.2f, \"max\": %.2f, \"avg\": %.2f",
           minV.value, maxV.value, avgV.value);
}

/* ── Print all spots as JSON array ──────────────────────────────────────── */

static void print_spots(ACS_ThermalImage *img)
{
    ACS_Measurements *meas = ACS_ThermalImage_getMeasurements(img);
    printf("  \"spots\": [\n");
    if (meas) {
        ACS_ListMeasurementSpot *spots = ACS_Measurements_getAllSpots(meas);
        size_t n = spots ? ACS_ListMeasurementSpot_size(spots) : 0;
        for (size_t i = 0; i < n; ++i) {
            ACS_MeasurementSpot *s = ACS_ListMeasurementSpot_item(spots, i);
            ACS_ThermalValue tv = ACS_MeasurementSpot_getValue(s);
            ACS_Point pos = ACS_MeasurementSpot_getPosition(s);
            const ACS_MeasurementShape *sh = ACS_MeasurementSpot_asMeasurementShape(s);
            int id = ACS_MeasurementShape_getId(sh);
            ACS_String *lbl = ACS_MeasurementShape_getLabel(sh);
            const char *l = lbl ? ACS_String_get(lbl) : "";
            printf("    { \"id\": %d, \"label\": \"%s\", \"x\": %d, \"y\": %d, "
                   "\"temperature\": %.2f, \"state\": %d }%s\n",
                   id, l, pos.x, pos.y, tv.value, tv.state,
                   (i + 1 < n) ? "," : "");
            if (lbl) ACS_String_free(lbl);
        }
        if (spots) ACS_ListMeasurementSpot_free(spots);
    }
    printf("  ]");
}

/* ═══════════════════════════════════════════════════════════════════════════
 *  COMMANDS
 * ═══════════════════════════════════════════════════════════════════════════ */

/* ── info ────────────────────────────────────────────────────────────────── */

static int cmd_info(const char *path)
{
    bool isThermal = ACS_ThermalImage_isThermalImageFromFile(path);
    if (!isThermal) {
        fail_json("not_thermal", "File does not contain radiometric FLIR data.");
        return 0;
    }

    ACS_ThermalImage *img = open_image(path);
    if (!img) return 1;

    int w = ACS_ThermalImage_getWidth(img);
    int h = ACS_ThermalImage_getHeight(img);

    printf("{\n  \"ok\": true,\n  \"width\": %d,\n  \"height\": %d,\n", w, h);

    /* Camera */
    ACS_Image_CameraInformation *cam = ACS_ThermalImage_getCameraInformation(img);
    if (cam) {
        printf("  \"camera\": { \"model\": \"%s\", \"serial\": \"%s\", \"lens\": \"%s\", "
               "\"filter\": \"%s\", \"programVersion\": \"%s\", "
               "\"rangeMin\": %.2f, \"rangeMax\": %.2f, \"horizontalFoV\": %d, \"focalLength\": %.2f },\n",
               ACS_Image_CameraInformation_getModelName(cam),
               ACS_Image_CameraInformation_getSerialNumber(cam),
               ACS_Image_CameraInformation_getLens(cam),
               ACS_Image_CameraInformation_getFilter(cam),
               ACS_Image_CameraInformation_getProgramVersion(cam),
               ACS_Image_CameraInformation_getRangeMin(cam).value,
               ACS_Image_CameraInformation_getRangeMax(cam).value,
               ACS_Image_CameraInformation_getHorizontalFoV(cam),
               ACS_Image_CameraInformation_getFocalLength(cam));
        ACS_Image_CameraInformation_free(cam);
    }

    /* Thermal params */
    ACS_ThermalParameters *tp = ACS_ThermalImage_getThermalParameters(img);
    if (tp) {
        printf("  \"thermalParams\": { \"emissivity\": %.4f, \"objectDistance\": %.2f, "
               "\"reflectedTemperature\": %.2f, \"atmosphericTemperature\": %.2f, "
               "\"relativeHumidity\": %.4f, \"atmosphericTransmission\": %.4f },\n",
               ACS_ThermalParameters_getObjectEmissivity(tp),
               ACS_ThermalParameters_getObjectDistance(tp),
               ACS_ThermalParameters_getObjectReflectedTemperature(tp).value,
               ACS_ThermalParameters_getAtmosphericTemperature(tp).value,
               ACS_ThermalParameters_getRelativeHumidity(tp),
               ACS_ThermalParameters_getAtmosphericTransmission(tp));
    }

    /* GPS */
    ACS_GpsInformation gps = ACS_ThermalImage_getGpsInformation(img);
    if (gps.isValid) {
        printf("  \"gps\": { \"latitude\": %.8f, \"longitude\": %.8f, \"altitude\": %.2f },\n",
               gps.latitude, gps.longitude, gps.altitude);
    }

    /* Compass */
    ACS_CompassInformation compass = ACS_ThermalImage_getCompassInformation(img);
    printf("  \"compass\": { \"degrees\": %d, \"pitch\": %d, \"roll\": %d, \"tilt\": %d },\n",
           compass.degrees, compass.pitch, compass.roll, compass.tilt);

    /* Color distribution */
    int cdm = ACS_ThermalImage_getColorDistributionMode(img);
    printf("  \"colorDistribution\": %d,\n", cdm);

    /* Scale */
    ACS_Scale *scale = ACS_ThermalImage_getScale(img);
    if (scale) {
        ACS_ThermalValue sMin = ACS_Scale_getScaleMin(scale);
        ACS_ThermalValue sMax = ACS_Scale_getScaleMax(scale);
        printf("  \"scale\": { \"min\": %.2f, \"max\": %.2f },\n", sMin.value, sMax.value);
    }

    /* Spots */
    print_spots(img);
    printf("\n}\n");

    ACS_ThermalImage_free(img);
    return 0;
}

/* ── render ──────────────────────────────────────────────────────────────── */

static int cmd_render(int argc, char **argv)
{
    /* render <image> <out.ppm> [palette] [colorDist] [scaleMin] [scaleMax] */
    if (argc < 4) { fail_json("args", "render requires <image> <out>"); return 1; }

    const char *path    = argv[2];
    const char *outPath = argv[3];

    ACS_ThermalImage *img = open_image(path);
    if (!img) return 1;

    if (argc >= 5)
        ACS_ThermalImage_setPalettePreset(img, palette_by_name(argv[4]));
    if (argc >= 6)
        ACS_ThermalImage_setColorDistributionMode(img, colordist_by_name(argv[5]));
    if (argc >= 8) {
        ACS_Scale *scale = ACS_ThermalImage_getScale(img);
        ACS_ThermalValue sMin = ACS_ThermalValue_fromCelsius(atof(argv[6]));
        ACS_ThermalValue sMax = ACS_ThermalValue_fromCelsius(atof(argv[7]));
        ACS_Scale_setScale(scale, sMin, sMax);
    }

    int rc = render_to_file(img, outPath);
    if (rc == 0) {
        int w = ACS_ThermalImage_getWidth(img);
        int h = ACS_ThermalImage_getHeight(img);
        printf("{ \"ok\": true, \"width\": %d, \"height\": %d, \"file\": \"%s\" }\n", w, h, outPath);
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── set-palette ─────────────────────────────────────────────────────────── */

static int cmd_set_palette(int argc, char **argv)
{
    if (argc < 5) { fail_json("args", "set-palette requires <image> <out> <preset>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    ACS_ThermalImage_setPalettePreset(img, palette_by_name(argv[4]));
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        const ACS_Palette *pal = ACS_ThermalImage_getPalette(img);
        printf("{ \"ok\": true, \"palette\": \"%s\" }\n", ACS_Palette_getName(pal));
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── set-scale ───────────────────────────────────────────────────────────── */

static int cmd_set_scale(int argc, char **argv)
{
    /* set-scale <image> <out> <min> <max> [palette] */
    if (argc < 6) { fail_json("args", "set-scale requires <image> <out> <min> <max>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    ACS_Scale *scale = ACS_ThermalImage_getScale(img);
    ACS_Scale_setScale(scale,
        ACS_ThermalValue_fromCelsius(atof(argv[4])),
        ACS_ThermalValue_fromCelsius(atof(argv[5])));

    if (argc >= 7)
        ACS_ThermalImage_setPalettePreset(img, palette_by_name(argv[6]));

    int rc = render_to_file(img, argv[3]);
    if (rc == 0) printf("{ \"ok\": true }\n");
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── set-colordist ───────────────────────────────────────────────────────── */

static int cmd_set_colordist(int argc, char **argv)
{
    if (argc < 5) { fail_json("args", "set-colordist requires <image> <out> <mode>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    ACS_ThermalImage_setColorDistributionMode(img, colordist_by_name(argv[4]));
    if (argc >= 6)
        ACS_ThermalImage_setPalettePreset(img, palette_by_name(argv[5]));

    int rc = render_to_file(img, argv[3]);
    if (rc == 0) printf("{ \"ok\": true }\n");
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── move-spot ───────────────────────────────────────────────────────────── */

static int cmd_move_spot(int argc, char **argv)
{
    if (argc < 7) { fail_json("args", "move-spot requires <image> <out> <id> <newX> <newY>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    int id = atoi(argv[4]), nx = atoi(argv[5]), ny = atoi(argv[6]);
    ACS_Measurements *meas = ACS_ThermalImage_getMeasurements(img);
    ACS_MeasurementSpot *spot = ACS_Measurements_moveSpot(meas, id, nx, ny);

    if (!spot) {
        ACS_ThermalImage_free(img);
        fail_json("move-spot", "spot id not found");
        return 1;
    }

    ACS_ThermalValue tv = ACS_MeasurementSpot_getValue(spot);

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        printf("{ \"ok\": true, \"id\": %d, \"x\": %d, \"y\": %d, \"temperature\": %.2f,\n",
               id, nx, ny, tv.value);
        print_spots(img);
        printf("\n}\n");
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── remove-spot ─────────────────────────────────────────────────────────── */

static int cmd_remove_spot(int argc, char **argv)
{
    if (argc < 5) { fail_json("args", "remove-spot requires <image> <out> <id>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    int id = atoi(argv[4]);
    ACS_Measurements *meas = ACS_ThermalImage_getMeasurements(img);
    bool ok = ACS_Measurements_removeSpot(meas, id);

    if (!ok) {
        ACS_ThermalImage_free(img);
        fail_json("remove-spot", "spot id not found");
        return 1;
    }

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        printf("{ \"ok\": true, \"id\": %d,\n", id);
        print_spots(img);
        printf("\n}\n");
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── add-spot ────────────────────────────────────────────────────────────── */

static int cmd_add_spot(int argc, char **argv)
{
    if (argc < 6) { fail_json("args", "add-spot requires <image> <out> <x> <y>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    int x = atoi(argv[4]), y = atoi(argv[5]);
    ACS_Measurements *meas = ACS_ThermalImage_getMeasurements(img);
    ACS_MeasurementSpot *spot = ACS_Measurements_addSpot(meas, x, y);

    ACS_ThermalValue tv = ACS_MeasurementSpot_getValue(spot);
    const ACS_MeasurementShape *sh = ACS_MeasurementSpot_asMeasurementShape(spot);
    int id = ACS_MeasurementShape_getId(sh);

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        printf("{ \"ok\": true, \"id\": %d, \"x\": %d, \"y\": %d, \"temperature\": %.2f,\n",
               id, x, y, tv.value);
        print_spots(img);
        printf("\n}\n");
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── add-rect ────────────────────────────────────────────────────────────── */

static int cmd_add_rect(int argc, char **argv)
{
    if (argc < 8) { fail_json("args", "add-rect requires <image> <out> <x> <y> <w> <h>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    int x = atoi(argv[4]), y = atoi(argv[5]);
    int w = atoi(argv[6]), h = atoi(argv[7]);
    ACS_Measurements *meas = ACS_ThermalImage_getMeasurements(img);
    ACS_MeasurementRectangle *rect = ACS_Measurements_addRectangle(meas, x, y, w, h, true, true);

    const ACS_MeasurementMarker *marker = ACS_MeasurementRectangle_asMeasurementMarker(rect);

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        printf("{ \"ok\": true, \"type\": \"rectangle\", ");
        print_marker_json(marker);
        printf(" }\n");
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── add-ellipse ─────────────────────────────────────────────────────────── */

static int cmd_add_ellipse(int argc, char **argv)
{
    if (argc < 8) { fail_json("args", "add-ellipse requires <image> <out> <cx> <cy> <rx> <ry>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    int cx = atoi(argv[4]), cy = atoi(argv[5]);
    int rx = atoi(argv[6]), ry = atoi(argv[7]);
    ACS_Measurements *meas = ACS_ThermalImage_getMeasurements(img);
    ACS_MeasurementEllipse *ell = ACS_Measurements_addEllipse(meas, cx, cy, rx, ry, true, true);

    const ACS_MeasurementMarker *marker = ACS_MeasurementEllipse_asMeasurementMarker(ell);

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        printf("{ \"ok\": true, \"type\": \"ellipse\", ");
        print_marker_json(marker);
        printf(" }\n");
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── add-line ────────────────────────────────────────────────────────────── */

static int cmd_add_line(int argc, char **argv)
{
    if (argc < 8) { fail_json("args", "add-line requires <image> <out> <x1> <y1> <x2> <y2>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    int x1 = atoi(argv[4]), y1 = atoi(argv[5]);
    int x2 = atoi(argv[6]), y2 = atoi(argv[7]);
    ACS_Measurements *meas = ACS_ThermalImage_getMeasurements(img);
    ACS_MeasurementLine *line = ACS_Measurements_addLine(meas, x1, y1, x2, y2, true, true);

    const ACS_MeasurementMarker *marker = ACS_MeasurementLine_asMeasurementMarker(line);

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        printf("{ \"ok\": true, \"type\": \"line\", ");
        print_marker_json(marker);
        printf(" }\n");
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── add-isotherm ────────────────────────────────────────────────────────── */

static int cmd_add_isotherm(int argc, char **argv)
{
    /* add-isotherm <image> <out> <above|below|interval> <temp1> [temp2] [palette] */
    if (argc < 6) { fail_json("args", "add-isotherm requires <image> <out> <type> <temp>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    const char *typeName = argv[4];
    double temp1 = atof(argv[5]);
    double temp2 = argc >= 7 ? atof(argv[6]) : temp1 + 5.0;

    /* Apply palette if given */
    if (argc >= 8)
        ACS_ThermalImage_setPalettePreset(img, palette_by_name(argv[7]));

    ACS_Isotherms *isos = ACS_ThermalImage_getIsotherms(img);

    ACS_Isotherm_Type isoType;
    if (strcasecmp(typeName, "above") == 0) {
        isoType = ACS_Isotherm_Type_getDefault(ACS_IsothermTypes_above);
        isoType.value.above.cutoff = ACS_ThermalValue_fromCelsius(temp1);
    } else if (strcasecmp(typeName, "below") == 0) {
        isoType = ACS_Isotherm_Type_getDefault(ACS_IsothermTypes_below);
        isoType.value.below.cutoff = ACS_ThermalValue_fromCelsius(temp1);
    } else {
        isoType = ACS_Isotherm_Type_getDefault(ACS_IsothermTypes_interval);
        isoType.value.interval.min = ACS_ThermalValue_fromCelsius(temp1);
        isoType.value.interval.max = ACS_ThermalValue_fromCelsius(temp2);
    }

    /* Red blended fill */
    ACS_Isotherm_FillMode fm;
    fm.type = ACS_FillModes_blendedColor;
    fm.value.color.blendingMode = ACS_BlendingMode_transparent;
    fm.value.color.color = ACS_Isotherms_Color_red();

    ACS_Isotherms_add(isos, &isoType, &fm);

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) printf("{ \"ok\": true, \"isotherm\": \"%s\" }\n", typeName);
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── set-params ──────────────────────────────────────────────────────────── */

static int cmd_set_params(int argc, char **argv)
{
    /* set-params <image> <out> <emissivity> <distance> <reflectedT> <humidity> [palette] */
    if (argc < 8) { fail_json("args", "set-params requires <image> <out> <e> <d> <rT> <h>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    double emissivity  = atof(argv[4]);
    double distance    = atof(argv[5]);
    double reflectedT  = atof(argv[6]);
    double humidity    = atof(argv[7]);

    ACS_ThermalParameters *tp = ACS_ThermalImage_getThermalParameters(img);
    if (tp) {
        ACS_ThermalParameters_setObjectEmissivity(tp, emissivity);
        ACS_ThermalParameters_setObjectDistance(tp, distance);
        ACS_ThermalParameters_setObjectReflectedTemperature(tp, ACS_ThermalValue_fromCelsius(reflectedT));
        ACS_ThermalParameters_setRelativeHumidity(tp, humidity);
    }

    if (argc >= 9)
        ACS_ThermalImage_setPalettePreset(img, palette_by_name(argv[8]));

    save_flir_inplace(img, argv[2]);
    int rc = render_to_file(img, argv[3]);
    if (rc == 0) {
        printf("{ \"ok\": true,\n");
        print_spots(img);
        printf("\n}\n");
    }
    ACS_ThermalImage_free(img);
    return rc;
}

/* ── get-temp ────────────────────────────────────────────────────────────── */

static int cmd_get_temp(int argc, char **argv)
{
    if (argc < 5) { fail_json("args", "get-temp requires <image> <x> <y>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    int x = atoi(argv[3]), y = atoi(argv[4]);
    ACS_ThermalValue tv = ACS_ThermalImage_getValueAt(img, x, y);

    printf("{ \"ok\": true, \"x\": %d, \"y\": %d, \"temperature\": %.2f, \"state\": %d }\n",
           x, y, tv.value, tv.state);
    ACS_ThermalImage_free(img);
    return 0;
}

/* ── save ────────────────────────────────────────────────────────────────── */

static int cmd_save(int argc, char **argv)
{
    if (argc < 4) { fail_json("args", "save requires <image> <out>"); return 1; }
    ACS_ThermalImage *img = open_image(argv[2]);
    if (!img) return 1;

    const char *outPath = argv[3];
    int format = ACS_FileFormat_jpeg;
    if (argc >= 5 && strcasecmp(argv[4], "fff") == 0)
        format = ACS_FileFormat_fff;

    ACS_NativeString *ns = ACS_NativeString_createFrom(outPath);
    ACS_ThermalImage_saveAs(img, ACS_NativeString_get(ns), format);
    ACS_NativeString_free(ns);

    if (check_error()) { ACS_ThermalImage_free(img); return 1; }
    printf("{ \"ok\": true, \"file\": \"%s\" }\n", outPath);
    ACS_ThermalImage_free(img);
    return 0;
}

/* ═══════════════════════════════════════════════════════════════════════════
 *  MAIN – dispatch commands
 * ═══════════════════════════════════════════════════════════════════════════ */

int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr,
            "Usage: flir_extract <command> [args...]\n"
            "Commands: info, render, set-palette, set-scale, set-colordist,\n"
            "          move-spot, remove-spot, add-spot, add-rect, add-ellipse, add-line,\n"
            "          add-isotherm, set-params, get-temp, save\n");
        return 1;
    }

    const char *cmd = argv[1];

    if (strcmp(cmd, "info") == 0 && argc >= 3)
        return cmd_info(argv[2]);
    if (strcmp(cmd, "render") == 0)
        return cmd_render(argc, argv);
    if (strcmp(cmd, "set-palette") == 0)
        return cmd_set_palette(argc, argv);
    if (strcmp(cmd, "set-scale") == 0)
        return cmd_set_scale(argc, argv);
    if (strcmp(cmd, "set-colordist") == 0)
        return cmd_set_colordist(argc, argv);
    if (strcmp(cmd, "move-spot") == 0)
        return cmd_move_spot(argc, argv);
    if (strcmp(cmd, "remove-spot") == 0)
        return cmd_remove_spot(argc, argv);
    if (strcmp(cmd, "add-spot") == 0)
        return cmd_add_spot(argc, argv);
    if (strcmp(cmd, "add-rect") == 0)
        return cmd_add_rect(argc, argv);
    if (strcmp(cmd, "add-ellipse") == 0)
        return cmd_add_ellipse(argc, argv);
    if (strcmp(cmd, "add-line") == 0)
        return cmd_add_line(argc, argv);
    if (strcmp(cmd, "add-isotherm") == 0)
        return cmd_add_isotherm(argc, argv);
    if (strcmp(cmd, "set-params") == 0)
        return cmd_set_params(argc, argv);
    if (strcmp(cmd, "get-temp") == 0)
        return cmd_get_temp(argc, argv);
    if (strcmp(cmd, "save") == 0)
        return cmd_save(argc, argv);

    /* Legacy: bare path = info */
    if (argc == 2)
        return cmd_info(argv[1]);

    fail_json("unknown_command", cmd);
    return 1;
}
