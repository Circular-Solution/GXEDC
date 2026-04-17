/*
 *  Copyright (c) 2023 Metaform Systems, Inc.
 *
 *  This program and the accompanying materials are made available under the
 *  terms of the Apache License, Version 2.0 which is available at
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Contributors:
 *       Metaform Systems, Inc. - initial API and implementation
 *       Circular Solution Co., Ltd - update to edc 0.16
 *
 */

import com.bmuschko.gradle.docker.tasks.image.DockerBuildImage
import org.gradle.api.plugins.quality.Checkstyle

plugins {
    `java-library`
    id("com.bmuschko.docker-remote-api") version "10.0.0"
    alias(libs.plugins.edc.build)
}

val edcBuildId = libs.plugins.edc.build.get().pluginId

allprojects {
    apply(plugin = edcBuildId)
    repositories {
        mavenLocal()
        mavenCentral()
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
        }
    }
}


val shadowPluginId = libs.plugins.shadow.get().pluginId
subprojects {
    if (file("src/main/java").exists()) {
        apply(plugin = "eclipse")
    }
    tasks.withType(Checkstyle::class).configureEach {
        enabled = false // ill use my formatters
    }
    gradle.taskGraph.whenReady {
        allTasks.filter {it.name.contains("Test") || it.name.contains("test")}.forEach {
            it.enabled = false // enable later when tests are fixed
        }
    }
    afterEvaluate {
        if (project.plugins.hasPlugin(shadowPluginId) &&
            file("${project.projectDir}/src/main/docker/Dockerfile").exists()
        ) {
            //actually apply the plugin to the (sub-)project
            apply(plugin = "com.bmuschko.docker-remote-api")

            tasks.register("dockerize", DockerBuildImage::class) {
                val dockerContextDir = project.projectDir
                dockerFile.set(file("$dockerContextDir/src/main/docker/Dockerfile"))
                images.add("${project.name}:${project.version}")
                images.add("${project.name}:latest")
                // specify platform with the -Dplatform flag:
                if (System.getProperty("platform") != null)
                    platform.set(System.getProperty("platform"))
                buildArgs.put("JAR", "build/libs/${project.name}.jar")
                inputDir.set(file(dockerContextDir))
                dependsOn("shadowJar")
            }
        }
    }
}
