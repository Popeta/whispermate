plugins {
    alias(libs.plugins.android.ai.pack)
}

aiPack {
    packName = "parakeet_v3_pack"

    dynamicDelivery {
        deliveryType = "on-demand"
    }
}
