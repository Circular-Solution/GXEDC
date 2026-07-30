plugins {
  `java-library`
}

dependencies {
  implementation(libs.edc.spi.boot)
  implementation(libs.edc.spi.participant)
  implementation(libs.edc.spi.policy.engine)
  implementation(libs.edc.spi.catalog)
  implementation(libs.edc.spi.contract)
  implementation(libs.edc.spi.transfer)
}
