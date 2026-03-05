package com.macro.mall.portal.component;

import com.macro.mall.portal.service.OmsPortalOrderService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitHandler;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 取消订单消息的处理者
 * Created by macro on 2018/9/14.
 */
@Component
public class CancelOrderReceiver {
    private static Logger LOGGER =LoggerFactory.getLogger(CancelOrderReceiver.class);
    @Autowired
    private OmsPortalOrderService portalOrderService;

    @RabbitListener(queues = "mall.order.cancel")
    public void handle(org.springframework.amqp.core.Message message){
        // Spring gives us the raw Message object when we listen at method level
        byte[] body = message.getBody();
        String text = new String(body);
        Long orderId = null;
        try {
            orderId = Long.valueOf(text.trim());
        } catch (NumberFormatException e) {
            LOGGER.warn("unable to parse orderId from message body [{}]", text);
        }
        if (orderId != null) {
            portalOrderService.cancelOrder(orderId);
            LOGGER.info("process orderId:{}", orderId);
        } else {
            LOGGER.warn("received unexpected message payload, cannot cancel order");
        }
    }
}
