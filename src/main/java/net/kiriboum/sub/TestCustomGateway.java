package net.kiriboum.sub;

import java.util.HashMap;
import java.util.Map;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import net.sourceforge.subsonic.service.SecurityService;
import net.sourceforge.subsonic.service.SettingsService;

import org.springframework.web.bind.ServletRequestBindingException;
import org.springframework.web.bind.ServletRequestUtils;
import org.springframework.web.servlet.ModelAndView;
import org.springframework.web.servlet.mvc.multiaction.MultiActionController;

public class TestCustomGateway extends MultiActionController{
    private SettingsService settingsService;
	private SecurityService securityService;

	private String getErrorMessage(Exception x) {
        if (x.getMessage() != null) {
            return x.getMessage();
        }
        return x.getClass().getSimpleName();
    }
    public ModelAndView kbgateway(HttpServletRequest request, HttpServletResponse response) throws Exception {


        String username;
        try {
            username = ServletRequestUtils.getRequiredStringParameter(request, "username");
        } catch (ServletRequestBindingException x) {
            //error(request, response, ErrorCode.MISSING_PARAMETER, getErrorMessage(x));
            //return;
        }
//        response.getWriter().print("Gateway finished");
        Map<String, Object> map = new HashMap<String, Object>();
        return new ModelAndView("kbgateway", "model", map);
    }
    public void setSettingsService(SettingsService settingsService) {
        this.settingsService = settingsService;
    }

    public void setSecurityService(SecurityService securityService) {
        this.securityService = securityService;
    }
}
