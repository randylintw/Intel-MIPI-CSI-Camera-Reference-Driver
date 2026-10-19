/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SSDT overlay: D457 (D4xx) GMSL camera configuration on PTL platform.
 *   Two MAX96724 deserializers (DES0, DES1) with CPHY connection to PTL platform,
 *   each carrying two D457 cameras over GMSL Links 0..1, fronted by MAX9295A serializers.
 *   Each D457 exposes four virtual channels (X/Y/Z/U) for its image streams.
 *
 * DES-level defines (set per DESx, undef'd at the end of each Device):
 *   DES_PHY_TYPE             - DES PHY type (0 for CPHY, 1 for DPHY)
 *   DES_I2C_ADDR             - DES I2C slave address (e.g. 0x0027 for MAX96724)
 *   DES_INTERNAL_PHY         - DES internal PHY (PHY0 = 4, PHY1 = 5, PHY2 = 6, PHY3 = 7)
 *   DES_TO_MIPI_PORT         - DES connected to IPU0 MIPI port (e.g. 0/1/2/3)
 *   DES_I2C_BUS              - DES I2C bus path (e.g. "\\_SB.PC00.I2C1")
 *   DES_PATH                 - DES ACPI path string (e.g. "\\_SB.PC00.DES0")
 *   DES_REF                  - DES ACPI namespace reference (e.g. \_SB.PC00.DES0)
 *   DES_PIPE_STR_AUTOSELECT  - DES pipe stream autoselect (0/1)
 *   I2C_SPEED                - I2C bus speed across DES, SER and CAM (e.g. 100000 for 100kHz)
 *
 * Channel-level defines (set per CHxx, undef'd by _des_ch_common_d457.asl):
 *   DESCH_LINK_NUM           - Channel/link number (0..3) - used for _ADR, reg, SER remote port
 *   DESCH_CH                 - Channel device name (e.g. CH00)
 *   DESCH_SER                - Serializer device name (e.g. SER0)
 *   DESCH_CAM                - Camera device name (e.g. CAM0)
 *   DESCH_SER_I2C            - SER I2C slave address (e.g. 0x40 for MAX9295A)
 *   DESCH_CH_PATH            - CHxx ACPI path string (e.g. "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH           - SERx ACPI path string (e.g. "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF            - SERx ACPI namespace reference (e.g. \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_GPIOREF        - SERx GPIO controller reference (e.g. ^^SER0)
 *   CAM_ALIAS                - Camera alias I2C address used in i2c-alias-pool of the SER
 *   CAM_LANES                - Number of MIPI data lanes for the camera (e.g. 2, 4)
 *   DESCH_SER_X_VC           - D457 X-stream virtual channel mapping (Package of VC indices)
 *   DESCH_SER_Y_VC           - D457 Y-stream virtual channel mapping
 *   DESCH_SER_Z_VC           - D457 Z-stream virtual channel mapping
 *   DESCH_SER_U_VC           - D457 U-stream virtual channel mapping
 *   DESCH_SER_EXTRA_GPIO_PIN - Optional: Extra SER GPIO pin number
 *   EXTERNAL_FRAME_SYNC      - Optional: Camera external frame sync FSIN GPIO enablement
 */

DefinitionBlock ("", "SSDT", 2, "", "IMG_IPU", 0x20260513)
{
    External (_SB.PC00, DeviceObj)

    Include ("_ipu.asl")

    Scope (\_SB.PC00)
    {
        Device (DES0)
        {
            // DES-level defines for DES0
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * DES-level defines expected by caller:
 *   DES_PHY_TYPE           - DES PHY type (0 for CPHY, 1 for DPHY), used in CSI2Bus
 *   DES_INTERNAL_PHY       - DES internal PHY (e.g. PHY0 = 4, PHY1 = 5, PHY2 = 6, PHY3 = 7), used as DES Local port in CSI2Bus.
 *   DES_LANES              - Number of MIPI data lanes (e.g. 2, 4), used in PRT4/5/6/7 connected to IPU
 *   DES_TO_MIPI_PORT       - DES connected to MIPI Port (e.g. 0/1/2) of IPU0 Device, used as IPU remote port in CSI2Bus
 *   DES_I2C_ADDR           - DES I2C slave address (e.g. 0x0027 for MAX96724), used in I2cSerialBusV2
 *   DES_I2C_BUS            - DES I2C bus path string (e.g. "\\_SB.PC00.I2C1"), used in I2cSerialBusV2
 *   DES_PATH               - Path to DES itself (e.g. "\\_SB.PC00.DESx"), used in GpioIo
 *   DES_REF                - ACPI namespace reference to DES itself (e.g. \\_SB.PC00.DESx), used in _DSD
 *                            gpio property (required if DES_FSIN_GPIO_PIN is defined)
 *   DES_PIPE_STR_AUTOSELECT - MAX96724 specific property
 *   DES_FSIN_GPIO_PIN      - (Optional) DES GPIO pin number, used in GpioIo (e.g. 7 for MFP7 on MAX96724,
 *                            used to receive the external GMSL frame sync trigger pulse)
 *   LINK_FREQ              - Optional link frequency; defaults to 1 GHz
 */


Name (_UID, Zero)               // _UID: Unique ID

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1139")         // MAX96724
}

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Name (_DEP, Package ()          // _DEP: Dependencies
{
    \_SB.PC00.IPU0              // Path to parent IPU0 (e.g. "\\_SB.PC00.IPU0")
})

Name (_CRS, ResourceTemplate () // _CRS: Current Resource Settings
{
    /* 
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * DESx Local Port -> IPU0 Remote Port
     * DESx PRT4/5/6/7 -> IPU0 PRT0/1/2/3
     */

    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        0,           // PhyType (e.g. 0 for CPHY, 1 for DPHY)
        6,       // LocalPort (e.g. 4/5/6/7 for DES internal PHY0/1/2/3)
        "\\_SB.PC00.IPU0",      // ResourceSource
        0,       // ResourceSourceIndex (e.g. 0/1/2/3 for parent IPU0 PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x0027,           // SlaveAddress (e.g. 0x0027 based on Deserializer Hardware)
        ControllerInitiated,    // SlaveMode
        100000,              // I2C ConnectionSpeed (e.g. 100000 for 100kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.I2C1",            // ResourceSource (e.g. "\\_SB.PC00.I2C1") based on Board design
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Addresses called out in the pool is used for Serializer for each link.
         */
        Package () { "i2c-alias-pool",  Package () { 0x44, 0x45, 0x46, 0x47 } },

        /*
         * MAX96724 specific handling for 3D sensor. Refer to max96724.c for implementation details.
         * pipe-stream-autoselect is enabled by default. Define it by caller to disable.
         */
        Package () { "pipe-stream-autoselect", 0 }, // Zero to disable, One to enable
        /*
         * External GMSL frame sync control, consumed by max96724.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (0/1) by the
         * caller to override.
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default

        /*
         * Name the GpioIo() resource above so drivers can fetch it via
         * gpiod_get(dev, "des-fsin", ...) instead of relying on _CRS index order.
         * Format: { ref, CRS GpioIo() index (0-based), pin index within that
         * resource, active_low }. This is the 1st (and only) GpioIo() resource
         * in _CRS, hence index 0; the pin index within it is also 0.
         */

    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to Link 0 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to Link 1 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-2", "PRT2" }, // Connected to Link 2 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-3", "PRT3" }, // Connected to Link 3 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-4", "PRT4" }, // Internal PHY0, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
        Package () { "mipi-img-port-5", "PRT5" }, // Internal PHY1, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
        Package () { "mipi-img-port-6", "PRT6" }, // Internal PHY2, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
        Package () { "mipi-img-port-7", "PRT7" }, // Internal PHY3, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
    }
})
Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4} },
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },

})

Name (PRT2, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } },
    },
})

Name (PRT3, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },

})

Name (PRT4, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1000000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})

Name (PRT5, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1000000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})

Name (PRT6, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1000000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})

Name (PRT7, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1000000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})


            // Channel 0
/* 
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * Description: Common template for each D457 GMSL camera under each deserializer link,
 *              where each link is represented as an ATR channel device.
 *
 * DES-level defines expected by caller:
 *   DES_PATH          - DESx ACPI path string (e.g., "\\_SB.PC00.DES0")
 *   DES_REF           - DESx ACPI namespace reference (e.g., \_SB.PC00.DES0)
 *
 * Channel-level defines expected by caller:
 *   DESCH_CH          - Channel device name (e.g., CH00)
 *   DESCH_SER         - Serializer device name (e.g., SER0)
 *   DESCH_CAM         - Camera device name (e.g., CAM0)
 *   DESCH_CH_PATH     - CHxx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH    - SERx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF     - SERx ACPI namespace reference (e.g., \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_I2C     - SERx I2C address (e.g., 0x40)
 *   DESCH_LINK_NUM    - Channel/link number (0, 1, 2, 3) - used for _ADR, reg, and SER remote port
 *   DESCH_SER_GPIOREF - SERx GPIO controller reference (e.g., ^^SER0, ^^SER1, etc.)
 *   CAM_LANES   - CAMx Number of MIPI data lanes for the camera (e.g., 2, 4)
 * Optional defines:
 *   DESCH_SER_EXTRA_GPIO_PIN - SERx Additional GPIO pin number (e.g., 7 for MFP7 in MAX9295A)
 *   DESCH_SER_X/Y/Z/U_VC     - SERx VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 */

Device (CH00) // New CHxx Device under parent DESx device for each DES channel/link
{
    /*
     * Channel is the naming convention used by i2c-mux or i2c-atr in ACPI namespace 
     * In GMSL context, it can directly be translated as Link 0/1/2/3 of the Deserializer
     */

    Name (_ADR, 0) // _ADR: Address for the channel (e.g. 0 for Link 0, 1 for Link 1)

    Name (_DSD, Package ()      // _DSD: Device Specific Data
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package ()
        {
            Package () { "reg", 0 },       // used by i2c-atr driver. Represents the channel / link number
        }
    })

    Device (SER0)      // SERx device under parent DESx.CHxx
    {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SER-level defines expected by caller:
 *   DES_REF              - Reference to parent DES (e.g. \_SB.PC00.DESx), used in _DEP
 *   DES_PATH             - Path to parent DES (e.g. "\\_SB.PC00.DESx"), used in CSI2Bus
 *   DESCH_CH_PATH        - Path to DES channel (e.g. "\\_SB.PC00.DESx.CHxx"), used in I2cSerialBusV2
 *   DESCH_SER_PATH       - Path to SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in GpioIo
 *   DESCH_LINK_NUM       - DES channel number (e.g. 0 for CH00, 1 for CH01), used in CSI2Bus
 *   DESCH_SER_I2C        - SER I2C slave address (e.g. 0x40, 0x62), used in I2cSerialBusV2
 *   CAM_ALIAS            - Camera alias I2C address used in i2c-alias-pool in _DSD
 *   DESCH_SER_EXTRA_GPIO_PIN - (Optional) SER Extra GPIO pin number, used in GpioIo
 *   DESCH_SER_FSYNC_RX_ID - (Optional) GMSL GPIO ID the DES sends frame sync as, used in MFP node
 *   DESCH_SER_X/Y/Z/U_VC - (Optional) SER VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 */

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1138")         // MAX9295A
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES0               // Path to parent DES (e.g. "\\_SB.PC00.DESx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * SERx Local Port -> DESx Remote Port
     * SERx PRT1 -> DESx PRT0/1/2/3
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        1,                      // LocalPort (MAX9295A only 1 PHY)
        "\\_SB.PC00.DES0",         // ResourceSource (Path to parent DES, e.g. "\\_SB.PC00.DESx")
        0,         // ResourceSourceIndex (e.g. 0/1/2/3 for parent DES PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x40,          // SlaveAddress (e.g. 0x40, 0x62 based on Serializer Hardware)
        ControllerInitiated,    // SlaveMode
        100000,              // I2C ConnectionSpeed (e.g. 100000 for 100kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES0.CH00",          // ResourceSource (e.g. "\\_SB.PC00.DESx.CHxx") based on which Link
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

    GpioIo (
        Exclusive,              // Shared (Not shared)
        PullNone,               // PinConfig (No need for pulls)
        0,                      // DebounceTimeout
        0,                      // DriveStrength
        IoRestrictionNone,      // IoRestriction
        "\\_SB.PC00.DES0.CH00.SER0",         // ResourceSourceIndex (Path to SER GPIO controller, e.g. "\\_SB.PC00.DESx.CHxx.SERx" based on which Link)
        0)                      // ResourceUsage (Must be 0)
    {
        0,                      // Pin 0 (e.g. MFP0 on MAX9295)
    }
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Address called out in the pool is used as Camera Alias Address.
         */
        Package () { "i2c-alias-pool",  Package() { 0x54 } },
        /*
         * External GMSL frame sync control, consumed by max96717.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (1) by the
         * caller to override.
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to CAMx (used by CAMx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to DESx PRTx (used by SERx CSI2Bus LocalPort)

        /* Below are for MAX96717 driver usage. Refer to max96717.c for implementation details */
        Package () { "Pipe-X", "PIPX" }, // Pipe X
        Package () { "Pipe-Y", "PIPY" }, // Pipe Y
        Package () { "Pipe-Z", "PIPZ" }, // Pipe Z
        Package () { "Pipe-U", "PIPU" }, // Pipe U
        Package () { "fsync", "MFP" }, // fsync pin configuration
    }
})

Name (MFP, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },       // 2 data lanes
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})

Name (PIPX, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },     // VC filter for pipe X
    },
})

Name (PIPY, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 1 } },     // VC filter for pipe Y
    },
})

Name (PIPZ, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 2 } },     // VC filter for pipe Z
    },
})

Name (PIPU, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 3 } },     // VC filter for pipe U
    },
})

        Device (CAM0)  // CAMx device under parent DESx.CHxx.SERx
        {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * CAM-level defines expected by caller:
 *   DESCH_SER_REF      - Path to parent SER (e.g. \_SB.PC00.DESx.CHxx.SERx), used in _DEP
 *   DESCH_SER_PATH     - Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in CSI2Bus and GpioIo
 *   DESCH_SER_GPIOREF  - GPIO controller path for SER (e.g. ^^SERx), used in gpio resources (e.g. reset-gpios)
 *   CAM_LANES    - Number of MIPI data lanes for the camera
 */
Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC10CD")         // D4XX
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES0.CH00.SER0               // Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * CAMx Local Port -> SERx Remote Port
     * CAMx PRT0 -> SERx PRT0
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        0,                      // LocalPort (D4XX only 1 PHY)
        "\\_SB.PC00.DES0.CH00.SER0",         // ResourceSource (Path to parent SERx, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0,                      // ResourceSourceIndex (e.g. 0 for SERx PRT0)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x0010,                 // SlaveAddress (0x10 based on D4XX hardware)
        ControllerInitiated,    // SlaveMode
        100000,              // I2C ConnectionSpeed (e.g. 100000 for 100kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES0.CH00.SER0",         // ResourceSource (Path to parent SER, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 96000000 }, // 96 MHz

        /*
         * Sensor specific GPIOs, reset-gpios will be used by d4xx.c
         * when devm_gpiod_get_optional is being called with "reset" consumer.
         * For details, please refer to ACPI GPIO binding documentation
         * https://www.kernel.org/doc/html/latest/firmware-guide/acpi/gpio-properties.html
         *
         * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
         * 0 is the GPIO pin group in parent SERx
         * 0 is the index of pin in the GPIO pin group in parent SERx
         * 1 is active low for reset
         *
         */
        Package () { "reset-gpios", Package () { ^^SER0, 0, 0, 1 } },
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to SERx PRTx (used by CAMx CSI2Bus LocalPort)
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },
    },
})
        }
    }
}


            // Clean up DES0-level defines
        }

        Device (DES1)
        {
            /*
             * For detailed explanation of each define, 
             * please refer to the comment block at the top of this file. 
             */

            // DES-level defines for DES1.
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * DES-level defines expected by caller:
 *   DES_PHY_TYPE           - DES PHY type (0 for CPHY, 1 for DPHY), used in CSI2Bus
 *   DES_INTERNAL_PHY       - DES internal PHY (e.g. PHY0 = 4, PHY1 = 5, PHY2 = 6, PHY3 = 7), used as DES Local port in CSI2Bus.
 *   DES_LANES              - Number of MIPI data lanes (e.g. 2, 4), used in PRT4/5/6/7 connected to IPU
 *   DES_TO_MIPI_PORT       - DES connected to MIPI Port (e.g. 0/1/2) of IPU0 Device, used as IPU remote port in CSI2Bus
 *   DES_I2C_ADDR           - DES I2C slave address (e.g. 0x0027 for MAX96724), used in I2cSerialBusV2
 *   DES_I2C_BUS            - DES I2C bus path string (e.g. "\\_SB.PC00.I2C1"), used in I2cSerialBusV2
 *   DES_PATH               - Path to DES itself (e.g. "\\_SB.PC00.DESx"), used in GpioIo
 *   DES_REF                - ACPI namespace reference to DES itself (e.g. \\_SB.PC00.DESx), used in _DSD
 *                            gpio property (required if DES_FSIN_GPIO_PIN is defined)
 *   DES_PIPE_STR_AUTOSELECT - MAX96724 specific property
 *   DES_FSIN_GPIO_PIN      - (Optional) DES GPIO pin number, used in GpioIo (e.g. 7 for MFP7 on MAX96724,
 *                            used to receive the external GMSL frame sync trigger pulse)
 *   LINK_FREQ              - Optional link frequency; defaults to 1 GHz
 */


Name (_UID, Zero)               // _UID: Unique ID

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1139")         // MAX96724
}

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Name (_DEP, Package ()          // _DEP: Dependencies
{
    \_SB.PC00.IPU0              // Path to parent IPU0 (e.g. "\\_SB.PC00.IPU0")
})

Name (_CRS, ResourceTemplate () // _CRS: Current Resource Settings
{
    /* 
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * DESx Local Port -> IPU0 Remote Port
     * DESx PRT4/5/6/7 -> IPU0 PRT0/1/2/3
     */

    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        0,           // PhyType (e.g. 0 for CPHY, 1 for DPHY)
        4,       // LocalPort (e.g. 4/5/6/7 for DES internal PHY0/1/2/3)
        "\\_SB.PC00.IPU0",      // ResourceSource
        2,       // ResourceSourceIndex (e.g. 0/1/2/3 for parent IPU0 PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x0027,           // SlaveAddress (e.g. 0x0027 based on Deserializer Hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.I2C0",            // ResourceSource (e.g. "\\_SB.PC00.I2C1") based on Board design
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Addresses called out in the pool is used for Serializer for each link.
         */
        Package () { "i2c-alias-pool",  Package () { 0x44, 0x45, 0x46, 0x47 } },

        /*
         * MAX96724 specific handling for 3D sensor. Refer to max96724.c for implementation details.
         * pipe-stream-autoselect is enabled by default. Define it by caller to disable.
         */
        Package () { "pipe-stream-autoselect", 1 }, // Enabled by default for usual 2D case
        /*
         * External GMSL frame sync control, consumed by max96724.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (0/1) by the
         * caller to override.
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default

        /*
         * Name the GpioIo() resource above so drivers can fetch it via
         * gpiod_get(dev, "des-fsin", ...) instead of relying on _CRS index order.
         * Format: { ref, CRS GpioIo() index (0-based), pin index within that
         * resource, active_low }. This is the 1st (and only) GpioIo() resource
         * in _CRS, hence index 0; the pin index within it is also 0.
         */

    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to Link 0 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to Link 1 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-2", "PRT2" }, // Connected to Link 2 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-3", "PRT3" }, // Connected to Link 3 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-4", "PRT4" }, // Internal PHY0, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
        Package () { "mipi-img-port-5", "PRT5" }, // Internal PHY1, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
        Package () { "mipi-img-port-6", "PRT6" }, // Internal PHY2, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
        Package () { "mipi-img-port-7", "PRT7" }, // Internal PHY3, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
    }
})
Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4} },
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },

})

Name (PRT2, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } },
    },
})

Name (PRT3, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },

})

Name (PRT4, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1250000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})

Name (PRT5, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1250000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})

Name (PRT6, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1250000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})

Name (PRT7, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },             // 2 lanes for CPHY/DPHY on Intel MIPI CRD
        Package () { "mipi-img-link-frequencies", Package() { 1250000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})


            // Channel-level defines for Channel 0 (CH00)
/* 
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * Description: Common template for each ISX031 GMSL camera under each deserializer link,
 *              where each link is represented as an ATR channel device.
 *
 * DES-level defines expected by caller:
 *   DES_PATH          - DESx ACPI path string (e.g., "\\_SB.PC00.DES0")
 *   DES_REF           - DESx ACPI namespace reference (e.g., \_SB.PC00.DES0)
 *
 * Channel-level defines expected by caller:
 *   DESCH_CH          - Channel device name (e.g., CH00)
 *   DESCH_SER         - Serializer device name (e.g., SER0)
 *   DESCH_CAM         - Camera device name (e.g., CAM0)
 *   DESCH_CH_PATH     - CHxx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH    - SERx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF     - SERx ACPI namespace reference (e.g., \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_I2C     - SERx I2C address (e.g., 0x40)
 *   DESCH_LINK_NUM    - Channel/link number (0, 1, 2, 3) - used for _ADR, reg, and SER remote port
 *   DESCH_SER_GPIOREF - SERx GPIO controller reference (e.g., ^^SER0, ^^SER1, etc.)
 *   CAM_LANES   - CAMx Number of MIPI data lanes for the camera (e.g., 2, 4)
 * Optional defines:
 *   DESCH_SER_EXTRA_GPIO_PIN - SERx Additional GPIO pin number (e.g., 7 for MFP7 in MAX9295A)
 *   DESCH_SER_X/Y/Z/U_VC - SERx VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 *   EXTERNAL_FRAME_SYNC  - CAMx Add fsin-gpio resource if defined
 */

Device (CH00) // New CHxx Device under parent DESx device for each DES channel/link
{
    /*
     * Channel is the naming convention used by i2c-mux or i2c-atr in ACPI namespace 
     * In GMSL context, it can directly be translated as Link 0/1/2/3 of the Deserializer
     */

    Name (_ADR, 0) // _ADR: Address for the channel (e.g. 0 for Link 0, 1 for Link 1)

    Name (_DSD, Package ()      // _DSD: Device Specific Data
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package ()
        {
            Package () { "reg", 0 },       // used by i2c-atr driver. Represents the channel / link number
        }
    })

    Device (SER0)      // SERx device under parent DESx.CHxx
    {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SER-level defines expected by caller:
 *   DES_REF              - Reference to parent DES (e.g. \_SB.PC00.DESx), used in _DEP
 *   DES_PATH             - Path to parent DES (e.g. "\\_SB.PC00.DESx"), used in CSI2Bus
 *   DESCH_CH_PATH        - Path to DES channel (e.g. "\\_SB.PC00.DESx.CHxx"), used in I2cSerialBusV2
 *   DESCH_SER_PATH       - Path to SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in GpioIo
 *   DESCH_LINK_NUM       - DES channel number (e.g. 0 for CH00, 1 for CH01), used in CSI2Bus
 *   DESCH_SER_I2C        - SER I2C slave address (e.g. 0x40, 0x62), used in I2cSerialBusV2
 *   CAM_ALIAS            - Camera alias I2C address used in i2c-alias-pool in _DSD
 *   DESCH_SER_EXTRA_GPIO_PIN - (Optional) SER Extra GPIO pin number, used in GpioIo
 *   DESCH_SER_FSYNC_RX_ID - (Optional) GMSL GPIO ID the DES sends frame sync as, used in MFP node
 *   DESCH_SER_X/Y/Z/U_VC - (Optional) SER VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 */

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1138")         // MAX9295A
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1               // Path to parent DES (e.g. "\\_SB.PC00.DESx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * SERx Local Port -> DESx Remote Port
     * SERx PRT1 -> DESx PRT0/1/2/3
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        1,                      // LocalPort (MAX9295A only 1 PHY)
        "\\_SB.PC00.DES1",         // ResourceSource (Path to parent DES, e.g. "\\_SB.PC00.DESx")
        0,         // ResourceSourceIndex (e.g. 0/1/2/3 for parent DES PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x40,          // SlaveAddress (e.g. 0x40, 0x62 based on Serializer Hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH00",          // ResourceSource (e.g. "\\_SB.PC00.DESx.CHxx") based on which Link
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

    GpioIo (
        Exclusive,              // Shared (Not shared)
        PullNone,               // PinConfig (No need for pulls)
        0,                      // DebounceTimeout
        0,                      // DriveStrength
        IoRestrictionNone,      // IoRestriction
        "\\_SB.PC00.DES1.CH00.SER0",         // ResourceSourceIndex (Path to SER GPIO controller, e.g. "\\_SB.PC00.DESx.CHxx.SERx" based on which Link)
        0)                      // ResourceUsage (Must be 0)
    {
        0,                      // Pin 0 (e.g. MFP0 on MAX9295)
    }
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Address called out in the pool is used as Camera Alias Address.
         */
        Package () { "i2c-alias-pool",  Package() { 0x54 } },
        /*
         * External GMSL frame sync control, consumed by max96717.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (1) by the
         * caller to override.
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to CAMx (used by CAMx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to DESx PRTx (used by SERx CSI2Bus LocalPort)

        /* Below are for MAX96717 driver usage. Refer to max96717.c for implementation details */
        Package () { "Pipe-X", "PIPX" }, // Pipe X
        Package () { "Pipe-Y", "PIPY" }, // Pipe Y
        Package () { "Pipe-Z", "PIPZ" }, // Pipe Z
        Package () { "Pipe-U", "PIPU" }, // Pipe U
        Package () { "fsync", "MFP" }, // fsync pin configuration
    }
})

Name (MFP, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // 4 data lanes
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // Default to 4 data lanes if not defined
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})

Name (PIPX, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPY, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPZ, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPU, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

        Device (CAM0)  // CAMx device under parent DESx.CHxx.SERx
        {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * CAM-level defines expected by caller:
 *   DESCH_SER_REF      - Path to parent SER (e.g. \_SB.PC00.DESx.CHxx.SERx), used in _DEP
 *   DESCH_SER_PATH     - Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in CSI2Bus and GpioIo
 *   DESCH_SER_GPIOREF  - GPIO controller path for SER (e.g. ^^SERx), used in gpio resources (e.g. reset-gpios)
 *   EXTERNAL_FRAME_SYNC - (Optional) Add fsin-gpio resource if defined
 *   CAM_LANES    - Number of MIPI data lanes for the camera
 */
Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC113C")         // ISX031
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1.CH00.SER0               // Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * CAMx Local Port -> SERx Remote Port
     * CAMx PRT0 -> SERx PRT0
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        0,                      // LocalPort (ISX031 only 1 PHY)
        "\\_SB.PC00.DES1.CH00.SER0",         // ResourceSource (Path to parent SERx, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0,                      // ResourceSourceIndex (e.g. 0 for SERx PRT0)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x001A,                 // SlaveAddress (0x1A based on ISX031 hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH00.SER0",         // ResourceSource (Path to parent SER, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 96000000 }, // 96 MHz

        /*
         * Sensor specific GPIOs, reset-gpios will be used by isx031.c
         * when devm_gpiod_get_optional is being called with "reset" consumer.
         * For details, please refer to ACPI GPIO binding documentation
         * https://www.kernel.org/doc/html/latest/firmware-guide/acpi/gpio-properties.html
         *
         * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
         * 0 is the GPIO pin group in parent SERx
         * 0 is the index of pin in the GPIO pin group in parent SERx
         * 1 is active low for reset
         * 
         */
        Package () { "reset-gpios", Package () { ^^SER0, 0, 0, 1 } },
        /*
        * FSIN GPIOs, fsin-gpios will be used by isx031.c
        * when devm_gpiod_get_optional is being called with "fsin" consumer.
        *
        * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
        * 0 is the GPIO pin group in parent SERx
        * 1 is the index of pin in the GPIO pin group in parent SERx
        * 1 is active low for FSIN
        *
        */
        /*
         * External GMSL frame sync control, consumed by isx031.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC to override
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to SERx PRTx (used by CAMx CSI2Bus LocalPort)
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})
        }
    }
}

            // Channel 1
/* 
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * Description: Common template for each ISX031 GMSL camera under each deserializer link,
 *              where each link is represented as an ATR channel device.
 *
 * DES-level defines expected by caller:
 *   DES_PATH          - DESx ACPI path string (e.g., "\\_SB.PC00.DES0")
 *   DES_REF           - DESx ACPI namespace reference (e.g., \_SB.PC00.DES0)
 *
 * Channel-level defines expected by caller:
 *   DESCH_CH          - Channel device name (e.g., CH00)
 *   DESCH_SER         - Serializer device name (e.g., SER0)
 *   DESCH_CAM         - Camera device name (e.g., CAM0)
 *   DESCH_CH_PATH     - CHxx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH    - SERx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF     - SERx ACPI namespace reference (e.g., \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_I2C     - SERx I2C address (e.g., 0x40)
 *   DESCH_LINK_NUM    - Channel/link number (0, 1, 2, 3) - used for _ADR, reg, and SER remote port
 *   DESCH_SER_GPIOREF - SERx GPIO controller reference (e.g., ^^SER0, ^^SER1, etc.)
 *   CAM_LANES   - CAMx Number of MIPI data lanes for the camera (e.g., 2, 4)
 * Optional defines:
 *   DESCH_SER_EXTRA_GPIO_PIN - SERx Additional GPIO pin number (e.g., 7 for MFP7 in MAX9295A)
 *   DESCH_SER_X/Y/Z/U_VC - SERx VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 *   EXTERNAL_FRAME_SYNC  - CAMx Add fsin-gpio resource if defined
 */

Device (CH01) // New CHxx Device under parent DESx device for each DES channel/link
{
    /*
     * Channel is the naming convention used by i2c-mux or i2c-atr in ACPI namespace 
     * In GMSL context, it can directly be translated as Link 0/1/2/3 of the Deserializer
     */

    Name (_ADR, 1) // _ADR: Address for the channel (e.g. 0 for Link 0, 1 for Link 1)

    Name (_DSD, Package ()      // _DSD: Device Specific Data
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package ()
        {
            Package () { "reg", 1 },       // used by i2c-atr driver. Represents the channel / link number
        }
    })

    Device (SER1)      // SERx device under parent DESx.CHxx
    {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SER-level defines expected by caller:
 *   DES_REF              - Reference to parent DES (e.g. \_SB.PC00.DESx), used in _DEP
 *   DES_PATH             - Path to parent DES (e.g. "\\_SB.PC00.DESx"), used in CSI2Bus
 *   DESCH_CH_PATH        - Path to DES channel (e.g. "\\_SB.PC00.DESx.CHxx"), used in I2cSerialBusV2
 *   DESCH_SER_PATH       - Path to SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in GpioIo
 *   DESCH_LINK_NUM       - DES channel number (e.g. 0 for CH00, 1 for CH01), used in CSI2Bus
 *   DESCH_SER_I2C        - SER I2C slave address (e.g. 0x40, 0x62), used in I2cSerialBusV2
 *   CAM_ALIAS            - Camera alias I2C address used in i2c-alias-pool in _DSD
 *   DESCH_SER_EXTRA_GPIO_PIN - (Optional) SER Extra GPIO pin number, used in GpioIo
 *   DESCH_SER_FSYNC_RX_ID - (Optional) GMSL GPIO ID the DES sends frame sync as, used in MFP node
 *   DESCH_SER_X/Y/Z/U_VC - (Optional) SER VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 */

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1138")         // MAX9295A
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1               // Path to parent DES (e.g. "\\_SB.PC00.DESx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * SERx Local Port -> DESx Remote Port
     * SERx PRT1 -> DESx PRT0/1/2/3
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        1,                      // LocalPort (MAX9295A only 1 PHY)
        "\\_SB.PC00.DES1",         // ResourceSource (Path to parent DES, e.g. "\\_SB.PC00.DESx")
        1,         // ResourceSourceIndex (e.g. 0/1/2/3 for parent DES PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x40,          // SlaveAddress (e.g. 0x40, 0x62 based on Serializer Hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH01",          // ResourceSource (e.g. "\\_SB.PC00.DESx.CHxx") based on which Link
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

    GpioIo (
        Exclusive,              // Shared (Not shared)
        PullNone,               // PinConfig (No need for pulls)
        0,                      // DebounceTimeout
        0,                      // DriveStrength
        IoRestrictionNone,      // IoRestriction
        "\\_SB.PC00.DES1.CH01.SER1",         // ResourceSourceIndex (Path to SER GPIO controller, e.g. "\\_SB.PC00.DESx.CHxx.SERx" based on which Link)
        0)                      // ResourceUsage (Must be 0)
    {
        0,                      // Pin 0 (e.g. MFP0 on MAX9295)
    }
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Address called out in the pool is used as Camera Alias Address.
         */
        Package () { "i2c-alias-pool",  Package() { 0x55 } },
        /*
         * External GMSL frame sync control, consumed by max96717.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (1) by the
         * caller to override.
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to CAMx (used by CAMx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to DESx PRTx (used by SERx CSI2Bus LocalPort)

        /* Below are for MAX96717 driver usage. Refer to max96717.c for implementation details */
        Package () { "Pipe-X", "PIPX" }, // Pipe X
        Package () { "Pipe-Y", "PIPY" }, // Pipe Y
        Package () { "Pipe-Z", "PIPZ" }, // Pipe Z
        Package () { "Pipe-U", "PIPU" }, // Pipe U
        Package () { "fsync", "MFP" }, // fsync pin configuration
    }
})

Name (MFP, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // 4 data lanes
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // Default to 4 data lanes if not defined
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})

Name (PIPX, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPY, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPZ, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPU, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

        Device (CAM1)  // CAMx device under parent DESx.CHxx.SERx
        {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * CAM-level defines expected by caller:
 *   DESCH_SER_REF      - Path to parent SER (e.g. \_SB.PC00.DESx.CHxx.SERx), used in _DEP
 *   DESCH_SER_PATH     - Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in CSI2Bus and GpioIo
 *   DESCH_SER_GPIOREF  - GPIO controller path for SER (e.g. ^^SERx), used in gpio resources (e.g. reset-gpios)
 *   EXTERNAL_FRAME_SYNC - (Optional) Add fsin-gpio resource if defined
 *   CAM_LANES    - Number of MIPI data lanes for the camera
 */
Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC113C")         // ISX031
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1.CH01.SER1               // Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * CAMx Local Port -> SERx Remote Port
     * CAMx PRT0 -> SERx PRT0
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        0,                      // LocalPort (ISX031 only 1 PHY)
        "\\_SB.PC00.DES1.CH01.SER1",         // ResourceSource (Path to parent SERx, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0,                      // ResourceSourceIndex (e.g. 0 for SERx PRT0)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x001A,                 // SlaveAddress (0x1A based on ISX031 hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH01.SER1",         // ResourceSource (Path to parent SER, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 96000000 }, // 96 MHz

        /*
         * Sensor specific GPIOs, reset-gpios will be used by isx031.c
         * when devm_gpiod_get_optional is being called with "reset" consumer.
         * For details, please refer to ACPI GPIO binding documentation
         * https://www.kernel.org/doc/html/latest/firmware-guide/acpi/gpio-properties.html
         *
         * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
         * 0 is the GPIO pin group in parent SERx
         * 0 is the index of pin in the GPIO pin group in parent SERx
         * 1 is active low for reset
         * 
         */
        Package () { "reset-gpios", Package () { ^^SER1, 0, 0, 1 } },
        /*
        * FSIN GPIOs, fsin-gpios will be used by isx031.c
        * when devm_gpiod_get_optional is being called with "fsin" consumer.
        *
        * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
        * 0 is the GPIO pin group in parent SERx
        * 1 is the index of pin in the GPIO pin group in parent SERx
        * 1 is active low for FSIN
        *
        */
        /*
         * External GMSL frame sync control, consumed by isx031.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC to override
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to SERx PRTx (used by CAMx CSI2Bus LocalPort)
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})
        }
    }
}

            // Channel 2
/* 
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * Description: Common template for each ISX031 GMSL camera under each deserializer link,
 *              where each link is represented as an ATR channel device.
 *
 * DES-level defines expected by caller:
 *   DES_PATH          - DESx ACPI path string (e.g., "\\_SB.PC00.DES0")
 *   DES_REF           - DESx ACPI namespace reference (e.g., \_SB.PC00.DES0)
 *
 * Channel-level defines expected by caller:
 *   DESCH_CH          - Channel device name (e.g., CH00)
 *   DESCH_SER         - Serializer device name (e.g., SER0)
 *   DESCH_CAM         - Camera device name (e.g., CAM0)
 *   DESCH_CH_PATH     - CHxx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH    - SERx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF     - SERx ACPI namespace reference (e.g., \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_I2C     - SERx I2C address (e.g., 0x40)
 *   DESCH_LINK_NUM    - Channel/link number (0, 1, 2, 3) - used for _ADR, reg, and SER remote port
 *   DESCH_SER_GPIOREF - SERx GPIO controller reference (e.g., ^^SER0, ^^SER1, etc.)
 *   CAM_LANES   - CAMx Number of MIPI data lanes for the camera (e.g., 2, 4)
 * Optional defines:
 *   DESCH_SER_EXTRA_GPIO_PIN - SERx Additional GPIO pin number (e.g., 7 for MFP7 in MAX9295A)
 *   DESCH_SER_X/Y/Z/U_VC - SERx VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 *   EXTERNAL_FRAME_SYNC  - CAMx Add fsin-gpio resource if defined
 */

Device (CH02) // New CHxx Device under parent DESx device for each DES channel/link
{
    /*
     * Channel is the naming convention used by i2c-mux or i2c-atr in ACPI namespace 
     * In GMSL context, it can directly be translated as Link 0/1/2/3 of the Deserializer
     */

    Name (_ADR, 2) // _ADR: Address for the channel (e.g. 0 for Link 0, 1 for Link 1)

    Name (_DSD, Package ()      // _DSD: Device Specific Data
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package ()
        {
            Package () { "reg", 2 },       // used by i2c-atr driver. Represents the channel / link number
        }
    })

    Device (SER2)      // SERx device under parent DESx.CHxx
    {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SER-level defines expected by caller:
 *   DES_REF              - Reference to parent DES (e.g. \_SB.PC00.DESx), used in _DEP
 *   DES_PATH             - Path to parent DES (e.g. "\\_SB.PC00.DESx"), used in CSI2Bus
 *   DESCH_CH_PATH        - Path to DES channel (e.g. "\\_SB.PC00.DESx.CHxx"), used in I2cSerialBusV2
 *   DESCH_SER_PATH       - Path to SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in GpioIo
 *   DESCH_LINK_NUM       - DES channel number (e.g. 0 for CH00, 1 for CH01), used in CSI2Bus
 *   DESCH_SER_I2C        - SER I2C slave address (e.g. 0x40, 0x62), used in I2cSerialBusV2
 *   CAM_ALIAS            - Camera alias I2C address used in i2c-alias-pool in _DSD
 *   DESCH_SER_EXTRA_GPIO_PIN - (Optional) SER Extra GPIO pin number, used in GpioIo
 *   DESCH_SER_FSYNC_RX_ID - (Optional) GMSL GPIO ID the DES sends frame sync as, used in MFP node
 *   DESCH_SER_X/Y/Z/U_VC - (Optional) SER VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 */

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1138")         // MAX9295A
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1               // Path to parent DES (e.g. "\\_SB.PC00.DESx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * SERx Local Port -> DESx Remote Port
     * SERx PRT1 -> DESx PRT0/1/2/3
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        1,                      // LocalPort (MAX9295A only 1 PHY)
        "\\_SB.PC00.DES1",         // ResourceSource (Path to parent DES, e.g. "\\_SB.PC00.DESx")
        2,         // ResourceSourceIndex (e.g. 0/1/2/3 for parent DES PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x40,          // SlaveAddress (e.g. 0x40, 0x62 based on Serializer Hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH02",          // ResourceSource (e.g. "\\_SB.PC00.DESx.CHxx") based on which Link
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

    GpioIo (
        Exclusive,              // Shared (Not shared)
        PullNone,               // PinConfig (No need for pulls)
        0,                      // DebounceTimeout
        0,                      // DriveStrength
        IoRestrictionNone,      // IoRestriction
        "\\_SB.PC00.DES1.CH02.SER2",         // ResourceSourceIndex (Path to SER GPIO controller, e.g. "\\_SB.PC00.DESx.CHxx.SERx" based on which Link)
        0)                      // ResourceUsage (Must be 0)
    {
        0,                      // Pin 0 (e.g. MFP0 on MAX9295)
    }
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Address called out in the pool is used as Camera Alias Address.
         */
        Package () { "i2c-alias-pool",  Package() { 0x56 } },
        /*
         * External GMSL frame sync control, consumed by max96717.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (1) by the
         * caller to override.
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to CAMx (used by CAMx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to DESx PRTx (used by SERx CSI2Bus LocalPort)

        /* Below are for MAX96717 driver usage. Refer to max96717.c for implementation details */
        Package () { "Pipe-X", "PIPX" }, // Pipe X
        Package () { "Pipe-Y", "PIPY" }, // Pipe Y
        Package () { "Pipe-Z", "PIPZ" }, // Pipe Z
        Package () { "Pipe-U", "PIPU" }, // Pipe U
        Package () { "fsync", "MFP" }, // fsync pin configuration
    }
})

Name (MFP, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // 4 data lanes
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // Default to 4 data lanes if not defined
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})

Name (PIPX, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPY, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPZ, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPU, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

        Device (CAM2)  // CAMx device under parent DESx.CHxx.SERx
        {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * CAM-level defines expected by caller:
 *   DESCH_SER_REF      - Path to parent SER (e.g. \_SB.PC00.DESx.CHxx.SERx), used in _DEP
 *   DESCH_SER_PATH     - Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in CSI2Bus and GpioIo
 *   DESCH_SER_GPIOREF  - GPIO controller path for SER (e.g. ^^SERx), used in gpio resources (e.g. reset-gpios)
 *   EXTERNAL_FRAME_SYNC - (Optional) Add fsin-gpio resource if defined
 *   CAM_LANES    - Number of MIPI data lanes for the camera
 */
Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC113C")         // ISX031
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1.CH02.SER2               // Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * CAMx Local Port -> SERx Remote Port
     * CAMx PRT0 -> SERx PRT0
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        0,                      // LocalPort (ISX031 only 1 PHY)
        "\\_SB.PC00.DES1.CH02.SER2",         // ResourceSource (Path to parent SERx, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0,                      // ResourceSourceIndex (e.g. 0 for SERx PRT0)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x001A,                 // SlaveAddress (0x1A based on ISX031 hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH02.SER2",         // ResourceSource (Path to parent SER, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 96000000 }, // 96 MHz

        /*
         * Sensor specific GPIOs, reset-gpios will be used by isx031.c
         * when devm_gpiod_get_optional is being called with "reset" consumer.
         * For details, please refer to ACPI GPIO binding documentation
         * https://www.kernel.org/doc/html/latest/firmware-guide/acpi/gpio-properties.html
         *
         * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
         * 0 is the GPIO pin group in parent SERx
         * 0 is the index of pin in the GPIO pin group in parent SERx
         * 1 is active low for reset
         * 
         */
        Package () { "reset-gpios", Package () { ^^SER2, 0, 0, 1 } },
        /*
        * FSIN GPIOs, fsin-gpios will be used by isx031.c
        * when devm_gpiod_get_optional is being called with "fsin" consumer.
        *
        * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
        * 0 is the GPIO pin group in parent SERx
        * 1 is the index of pin in the GPIO pin group in parent SERx
        * 1 is active low for FSIN
        *
        */
        /*
         * External GMSL frame sync control, consumed by isx031.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC to override
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to SERx PRTx (used by CAMx CSI2Bus LocalPort)
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})
        }
    }
}

            // Channel 3
/* 
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * Description: Common template for each ISX031 GMSL camera under each deserializer link,
 *              where each link is represented as an ATR channel device.
 *
 * DES-level defines expected by caller:
 *   DES_PATH          - DESx ACPI path string (e.g., "\\_SB.PC00.DES0")
 *   DES_REF           - DESx ACPI namespace reference (e.g., \_SB.PC00.DES0)
 *
 * Channel-level defines expected by caller:
 *   DESCH_CH          - Channel device name (e.g., CH00)
 *   DESCH_SER         - Serializer device name (e.g., SER0)
 *   DESCH_CAM         - Camera device name (e.g., CAM0)
 *   DESCH_CH_PATH     - CHxx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH    - SERx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF     - SERx ACPI namespace reference (e.g., \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_I2C     - SERx I2C address (e.g., 0x40)
 *   DESCH_LINK_NUM    - Channel/link number (0, 1, 2, 3) - used for _ADR, reg, and SER remote port
 *   DESCH_SER_GPIOREF - SERx GPIO controller reference (e.g., ^^SER0, ^^SER1, etc.)
 *   CAM_LANES   - CAMx Number of MIPI data lanes for the camera (e.g., 2, 4)
 * Optional defines:
 *   DESCH_SER_EXTRA_GPIO_PIN - SERx Additional GPIO pin number (e.g., 7 for MFP7 in MAX9295A)
 *   DESCH_SER_X/Y/Z/U_VC - SERx VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 *   EXTERNAL_FRAME_SYNC  - CAMx Add fsin-gpio resource if defined
 */

Device (CH03) // New CHxx Device under parent DESx device for each DES channel/link
{
    /*
     * Channel is the naming convention used by i2c-mux or i2c-atr in ACPI namespace 
     * In GMSL context, it can directly be translated as Link 0/1/2/3 of the Deserializer
     */

    Name (_ADR, 3) // _ADR: Address for the channel (e.g. 0 for Link 0, 1 for Link 1)

    Name (_DSD, Package ()      // _DSD: Device Specific Data
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package ()
        {
            Package () { "reg", 3 },       // used by i2c-atr driver. Represents the channel / link number
        }
    })

    Device (SER3)      // SERx device under parent DESx.CHxx
    {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SER-level defines expected by caller:
 *   DES_REF              - Reference to parent DES (e.g. \_SB.PC00.DESx), used in _DEP
 *   DES_PATH             - Path to parent DES (e.g. "\\_SB.PC00.DESx"), used in CSI2Bus
 *   DESCH_CH_PATH        - Path to DES channel (e.g. "\\_SB.PC00.DESx.CHxx"), used in I2cSerialBusV2
 *   DESCH_SER_PATH       - Path to SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in GpioIo
 *   DESCH_LINK_NUM       - DES channel number (e.g. 0 for CH00, 1 for CH01), used in CSI2Bus
 *   DESCH_SER_I2C        - SER I2C slave address (e.g. 0x40, 0x62), used in I2cSerialBusV2
 *   CAM_ALIAS            - Camera alias I2C address used in i2c-alias-pool in _DSD
 *   DESCH_SER_EXTRA_GPIO_PIN - (Optional) SER Extra GPIO pin number, used in GpioIo
 *   DESCH_SER_FSYNC_RX_ID - (Optional) GMSL GPIO ID the DES sends frame sync as, used in MFP node
 *   DESCH_SER_X/Y/Z/U_VC - (Optional) SER VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 */

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1138")         // MAX9295A
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1               // Path to parent DES (e.g. "\\_SB.PC00.DESx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * SERx Local Port -> DESx Remote Port
     * SERx PRT1 -> DESx PRT0/1/2/3
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        1,                      // LocalPort (MAX9295A only 1 PHY)
        "\\_SB.PC00.DES1",         // ResourceSource (Path to parent DES, e.g. "\\_SB.PC00.DESx")
        3,         // ResourceSourceIndex (e.g. 0/1/2/3 for parent DES PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x40,          // SlaveAddress (e.g. 0x40, 0x62 based on Serializer Hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH03",          // ResourceSource (e.g. "\\_SB.PC00.DESx.CHxx") based on which Link
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

    GpioIo (
        Exclusive,              // Shared (Not shared)
        PullNone,               // PinConfig (No need for pulls)
        0,                      // DebounceTimeout
        0,                      // DriveStrength
        IoRestrictionNone,      // IoRestriction
        "\\_SB.PC00.DES1.CH03.SER3",         // ResourceSourceIndex (Path to SER GPIO controller, e.g. "\\_SB.PC00.DESx.CHxx.SERx" based on which Link)
        0)                      // ResourceUsage (Must be 0)
    {
        0,                      // Pin 0 (e.g. MFP0 on MAX9295)
    }
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Address called out in the pool is used as Camera Alias Address.
         */
        Package () { "i2c-alias-pool",  Package() { 0x57 } },
        /*
         * External GMSL frame sync control, consumed by max96717.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (1) by the
         * caller to override.
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to CAMx (used by CAMx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to DESx PRTx (used by SERx CSI2Bus LocalPort)

        /* Below are for MAX96717 driver usage. Refer to max96717.c for implementation details */
        Package () { "Pipe-X", "PIPX" }, // Pipe X
        Package () { "Pipe-Y", "PIPY" }, // Pipe Y
        Package () { "Pipe-Z", "PIPZ" }, // Pipe Z
        Package () { "Pipe-U", "PIPU" }, // Pipe U
        Package () { "fsync", "MFP" }, // fsync pin configuration
    }
})

Name (MFP, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // 4 data lanes
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // Default to 4 data lanes if not defined
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})

Name (PIPX, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPY, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPZ, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

Name (PIPU, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
    },
})

        Device (CAM3)  // CAMx device under parent DESx.CHxx.SERx
        {
/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * CAM-level defines expected by caller:
 *   DESCH_SER_REF      - Path to parent SER (e.g. \_SB.PC00.DESx.CHxx.SERx), used in _DEP
 *   DESCH_SER_PATH     - Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in CSI2Bus and GpioIo
 *   DESCH_SER_GPIOREF  - GPIO controller path for SER (e.g. ^^SERx), used in gpio resources (e.g. reset-gpios)
 *   EXTERNAL_FRAME_SYNC - (Optional) Add fsin-gpio resource if defined
 *   CAM_LANES    - Number of MIPI data lanes for the camera
 */
Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC113C")         // ISX031
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    \_SB.PC00.DES1.CH03.SER3               // Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * CAMx Local Port -> SERx Remote Port
     * CAMx PRT0 -> SERx PRT0
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        0,                      // LocalPort (ISX031 only 1 PHY)
        "\\_SB.PC00.DES1.CH03.SER3",         // ResourceSource (Path to parent SERx, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0,                      // ResourceSourceIndex (e.g. 0 for SERx PRT0)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x001A,                 // SlaveAddress (0x1A based on ISX031 hardware)
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
        AddressingMode7Bit,     // AddressingMode
        "\\_SB.PC00.DES1.CH03.SER3",         // ResourceSource (Path to parent SER, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 96000000 }, // 96 MHz

        /*
         * Sensor specific GPIOs, reset-gpios will be used by isx031.c
         * when devm_gpiod_get_optional is being called with "reset" consumer.
         * For details, please refer to ACPI GPIO binding documentation
         * https://www.kernel.org/doc/html/latest/firmware-guide/acpi/gpio-properties.html
         *
         * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
         * 0 is the GPIO pin group in parent SERx
         * 0 is the index of pin in the GPIO pin group in parent SERx
         * 1 is active low for reset
         * 
         */
        Package () { "reset-gpios", Package () { ^^SER3, 0, 0, 1 } },
        /*
        * FSIN GPIOs, fsin-gpios will be used by isx031.c
        * when devm_gpiod_get_optional is being called with "fsin" consumer.
        *
        * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
        * 0 is the GPIO pin group in parent SERx
        * 1 is the index of pin in the GPIO pin group in parent SERx
        * 1 is active low for FSIN
        *
        */
        /*
         * External GMSL frame sync control, consumed by isx031.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC to override
         */
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to SERx PRTx (used by CAMx CSI2Bus LocalPort)
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})
        }
    }
}

            // Clean up DES1-level defines
        }
    }
}
