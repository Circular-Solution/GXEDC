plugins {
	`java-library`
}

dependencies {
	api(libs.edc.spi.core)
	api(libs.edc.ih.spi)
	api(libs.edc.ih.spi.oid4vci)
	api(libs.edc.ih.spi.credentials)
	implementation(libs.edc.spi.boot)
	implementation(libs.nimbus.jwt)
	implementation("com.squareup.okhttp3:okhttp:5.0.0-alpha.12")
}
