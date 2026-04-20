plugins {
	`java-library`
}

dependencies {
	api(project(":extensions:gx-issuer"))
	implementation(libs.edc.spi.core)
	implementation(libs.edc.spi.boot)
    implementation("software.amazon.awssdk:s3:2.25.35")
}
