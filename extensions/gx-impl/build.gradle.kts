plugins {
  `java-library`
}

dependencies {
  api(libs.edc.spi.vc)
  implementation(libs.edc.spi.boot)
  implementation(libs.edc.spi.participant)
  implementation(libs.edc.spi.policy.engine)
  implementation(libs.edc.spi.catalog)
  implementation(libs.edc.spi.contract)
  implementation(libs.edc.spi.transfer)
  implementation("com.squareup.okhttp3:okhttp:5.0.0-alpha.12")
}
