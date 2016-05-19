/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

/*
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "AP_Notify.h"

extern const AP_HAL::HAL& hal;

void onOff(uint8_t pin, uint8_t value);
void onOff(uint8_t pin, uint8_t value)
{
	hal.gpio->write(pin, value);
	int8_t relay = -1;
	if(pin == HAL_GPIO_A_LED_PIN)
		relay = 0;
	else if(pin == HAL_GPIO_C_LED_PIN)
		relay = 1;
	
	if(AP_Notify::apm_relay && relay != -1)
    {
    	if(value == HAL_GPIO_LED_ON)
    	{
    		AP_Notify::apm_relay->on(relay);
    	}
    	else
    	{
    		AP_Notify::apm_relay->off(relay);
    	}
    }
}

const AP_Param::GroupInfo AP_BoardLED::var_info[] PROGMEM = {
    AP_GROUPINFO("RED_LED_RELAY",  0, AP_BoardLED, _red_led_relay, -1),
    AP_GROUPINFO("BLUE_LED_RELAY",  0, AP_BoardLED, _blue_led_relay, -1),
    AP_GROUPEND
};

AP_BoardLED::AP_BoardLED(void)
{
}

bool AP_BoardLED::init(void)
{
    // setup the main LEDs as outputs
    hal.gpio->pinMode(HAL_GPIO_A_LED_PIN, HAL_GPIO_OUTPUT);
    hal.gpio->pinMode(HAL_GPIO_B_LED_PIN, HAL_GPIO_OUTPUT);
    hal.gpio->pinMode(HAL_GPIO_C_LED_PIN, HAL_GPIO_OUTPUT);

    if(AP_Notify::apm_relay)
    {
    	AP_Notify::apm_relay->init();
    }

    // turn all lights off
    onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_OFF);
    onOff(HAL_GPIO_B_LED_PIN, HAL_GPIO_LED_OFF);
    onOff(HAL_GPIO_C_LED_PIN, HAL_GPIO_LED_OFF);
    
    
    return true;
}



/*
  main update function called at 50Hz
 */
void AP_BoardLED::update(void)
{
    _counter++;

    // we never want to update LEDs at a higher than 16Hz rate
    if (_counter % 3 != 0) {
        return;
    }

    // counter2 used to drop frequency down to 16hz
    uint8_t counter2 = _counter / 3;

    // initialising
    if (AP_Notify::flags.initialising) {
        // blink LEDs A and C at 8Hz (full cycle) during initialisation
        if (counter2 & 1) {
            onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_ON);
            onOff(HAL_GPIO_C_LED_PIN, HAL_GPIO_LED_OFF);
        } else {
            onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_OFF);
            onOff(HAL_GPIO_C_LED_PIN, HAL_GPIO_LED_ON);
        }
        return;
	}

    // save trim and ESC calibration
    if (AP_Notify::flags.save_trim || AP_Notify::flags.esc_calibration) {
        static uint8_t save_trim_counter = 0;
        if ((counter2 & 0x2) == 0) {
            save_trim_counter++;
        }
        switch(save_trim_counter) {
            case 0:
                onOff(HAL_GPIO_C_LED_PIN, HAL_GPIO_LED_OFF);
                onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_ON);
                break;

            case 1:
                onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_OFF);
                onOff(HAL_GPIO_B_LED_PIN, HAL_GPIO_LED_ON);
                break;

            case 2:
                onOff(HAL_GPIO_B_LED_PIN, HAL_GPIO_LED_OFF);
                onOff(HAL_GPIO_C_LED_PIN, HAL_GPIO_LED_ON);
                break;

            default:
                save_trim_counter = -1;
                break;
        }
        return;
    }

    // arming light
    static uint8_t arm_counter = 0;
	if (AP_Notify::flags.armed) {
        // red led solid
        onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_ON);
    }else{
        if ((counter2 & 0x2) == 0) {
            arm_counter++;
        }
        if (AP_Notify::flags.pre_arm_check) {
            // passed pre-arm checks so slower single flash
            switch(arm_counter) {
                case 0:
                case 1:
                case 2:
                    onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_ON);
                    break;
                case 3:
                case 4:
                case 5:
                    onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_OFF);
                    break;
                default:
                    // reset counter to restart the sequence
                    arm_counter = -1;
                    break;
            }
        }else{
            // failed pre-arm checks so double flash
            switch(arm_counter) {
                case 0:
                case 1:
                    onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_ON);
                    break;
                case 2:
                    onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_OFF);
                    break;
                case 3:
                case 4:
                    onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_ON);
                    break;
                case 5:
                case 6:
                    onOff(HAL_GPIO_A_LED_PIN, HAL_GPIO_LED_OFF);
                    break;
                default:
                    arm_counter = -1;
                    break;
            }
        }
    }

    // gps light
    switch (AP_Notify::flags.gps_status) {
        case 0:
            // no GPS attached
            onOff(HAL_GPIO_C_LED_PIN, HAL_GPIO_LED_OFF);
            break;

        case 1:
            // GPS attached but no lock, blink at 4Hz
            if ((counter2 & 0x3) == 0) {
                hal.gpio->toggle(HAL_GPIO_C_LED_PIN);
            }
            break;

        case 2:
            // GPS attached but 2D lock, blink more slowly (around 2Hz)
            if ((counter2 & 0x7) == 0) {
                hal.gpio->toggle(HAL_GPIO_C_LED_PIN);
            }
            break;

        default:
            // solid blue on gps lock
            onOff(HAL_GPIO_C_LED_PIN, HAL_GPIO_LED_ON);
            break;        
    }
}
