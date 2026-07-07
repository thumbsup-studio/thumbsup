package studio.thumbsup.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class ThumbsupServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ThumbsupServerApplication.class, args);
    }
}
