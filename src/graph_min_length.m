function [G, x, y] = graph_min_length(G, x, y, min_len)
% Enforce minimum edge length
% probably adjust 0.5

for iter = 1:10
    for e = 1:numedges(G)
        i = G.Edges.EndNodes(e,1);
        j = G.Edges.EndNodes(e,2);

        dx = x(j) - x(i);
        dy = y(j) - y(i);
        d = hypot(dx, dy);

        if d < min_len && d > 0
            push = 0.5 * (min_len - d);
            ux = dx / d;
            uy = dy / d;

            x(i) = x(i) - push * ux;
            y(i) = y(i) - push * uy;
            x(j) = x(j) + push * ux;
            y(j) = y(j) + push * uy;
        end
    end
end

G = G;
x = x;
y = y;

end
