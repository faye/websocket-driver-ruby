import java.io.IOException;

import com.jcoglan.websocket.Frame;
import com.jcoglan.websocket.Message;
import com.jcoglan.websocket.Observer;
import com.jcoglan.websocket.Parser;

import org.jruby.Ruby;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyFixnum;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.RubySymbol;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.BasicLibraryService;

public class WebsocketDriverService implements BasicLibraryService {
    private Ruby runtime;

    public boolean basicLoad(Ruby runtime) throws IOException {
        this.runtime = runtime;
        RubyModule websocket = runtime.defineModule("WebSocketNative");

        RubyClass parser = websocket.defineClassUnder("Parser", runtime.getObject(), new ObjectAllocator() {
            public IRubyObject allocate(Ruby runtime, RubyClass rubyClass) {
                return new RParser(runtime, rubyClass);
            }
        });
        parser.defineAnnotatedMethods(RParser.class);
        return true;
    }

    public class RParser extends RubyObject {
        private Parser parser;
        private Ruby runtime;

        public RParser(final Ruby runtime, RubyClass rubyClass) {
            super(runtime, rubyClass);
            this.runtime = runtime;
        }

        @JRubyMethod
        public IRubyObject initialize(final ThreadContext context, final IRubyObject driver, IRubyObject requireMasking) {
            Observer observer = new Observer() {
                public void onError(int code, String reason) {
                    IRubyObject[] args = {symbol("handle_error"), fixnum(code), string(reason.getBytes())};
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onMessage(Message message) {
                    IRubyObject[] args = {
                        symbol("handle_message"),
                        fixnum(message.opcode),
                        bool(message.rsv1),
                        bool(message.rsv2),
                        bool(message.rsv3),
                        string(message.copy())
                    };
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onClose(int code, byte[] reason) {
                    IRubyObject[] args = {symbol("handle_close"), fixnum(code), string(reason)};
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onPing(Frame frame) {
                    IRubyObject[] args = {symbol("handle_ping"), string(frame.payload)};
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onPong(Frame frame) {
                    IRubyObject[] args = {symbol("handle_pong"), string(frame.payload)};
                    ((RubyObject)driver).send(context, args, null);
                }

                private RubyBoolean bool(boolean value) {
                    return RubyBoolean.newBoolean(runtime, value);
                }

                private RubyFixnum fixnum(int value) {
                    return RubyFixnum.newFixnum(runtime, value);
                }

                private RubySymbol symbol(String name) {
                    return RubySymbol.newSymbol(runtime, name);
                }

                private RubyString string(byte[] value) {
                    return new RubyString(runtime, RubyString.createStringClass(runtime), value);
                }
            };

            parser = new Parser(observer, requireMasking.isTrue());
            return null;
        }

        @JRubyMethod
        public IRubyObject parse(IRubyObject chunk) {
            byte[] bytes = ((RubyString)chunk).getBytes();
            parser.parse(bytes);
            return null;
        }
    }
}
