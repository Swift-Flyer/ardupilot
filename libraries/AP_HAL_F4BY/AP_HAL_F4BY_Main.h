#ifndef __AP_HAL_F4BY_MAIN_H__
#define __AP_HAL_F4BY_MAIN_H__

#if CONFIG_HAL_BOARD == HAL_BOARD_F4BY

#define AP_HAL_MAIN() \
    extern "C" __EXPORT int SKETCH_MAIN(int argc, char * const argv[]); \
    int SKETCH_MAIN(int argc, char * const argv[]) {	\
	hal.init(argc, argv); \
	return OK; \
    }

#endif
#endif // __AP_HAL_F4BY_MAIN_H__
