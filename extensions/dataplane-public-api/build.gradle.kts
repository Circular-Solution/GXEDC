plugins {
  `java-library`
}

dependencies {
  implementation(libs.edc.spi.dataplane)
  implementation(libs.edc.spi.web)
  implementation(libs.edc.dataplane.util)
}
