allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // flutter_stripe (PaymentSheet) and flutter_stripe_connect (embedded
    // onboarding) each pin their own Stripe Android SDK release, and the
    // SDK's modules must all be the same version. Hold every 23.x module
    // at the release flutter_stripe is built against, so customer
    // payments run on exactly the SDK they were tested with. Bump this
    // together with flutter_stripe (see stripe_android's build.gradle).
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.stripe" && requested.version?.startsWith("23.") == true) {
                useVersion("23.22.0")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
