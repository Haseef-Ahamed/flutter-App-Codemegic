import java.io.File

import java.util.*



val keystoreProperties =

    Properties().apply {

        var file = File("key.properties")

        if (file.exists()) load(file.reader())

    }



plugins { ... }



android {

    ...

    val appVersionCode = (System.getenv()["NEW_BUILD_NUMBER"] ?: "1")?.toInt()

    defaultConfig {

        ...

        versionCode = appVersionCode

        ...

    }

    signingConfigs {

        create("release") {

            if (System.getenv()["CI"].toBoolean()) { // CI=true is exported by Codemagic

                storeFile = file(System.getenv()["CM_KEYSTORE_PATH"])

                storePassword = System.getenv()["CM_KEYSTORE_PASSWORD"]

                keyAlias = System.getenv()["CM_KEY_ALIAS"]

                keyPassword = System.getenv()["CM_KEY_PASSWORD"]

            } else {

                storeFile = file(keystoreProperties.getProperty("storeFile"))

                storePassword = keystoreProperties.getProperty("storePassword")

                keyAlias = keystoreProperties.getProperty("keyAlias")

                keyPassword = keystoreProperties.getProperty("keyPassword")

            }

        }

    }

    buildTypes {

        getByName("release") {

            isMinifyEnabled = false

            signingConfig = signingConfigs.getByName("release")

        }

    }

}



dependencies { ... }